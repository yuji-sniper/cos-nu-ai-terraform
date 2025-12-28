import { DynamoDBClient, GetItemCommand, PutItemCommand } from "@aws-sdk/client-dynamodb"
import { getRunningComfyUiUrl } from "./instance.mjs"

const DYNAMODB_GENERATION_JOB_TABLE_NAME = process.env.DYNAMODB_GENERATION_JOB_TABLE_NAME
const DYNAMODB_COMFYUI_LAST_ACCESS_AT_TABLE_NAME = process.env.DYNAMODB_COMFYUI_LAST_ACCESS_AT_TABLE_NAME
const API_HEADERS = {
  "Content-Type": "application/json"
}
const MAX_POLL_COUNT = 60
const POLL_INTERVAL = 5000

const ddb = new DynamoDBClient({})

/**
 * エラーハンドリング
 * ※ 例外を投げることでデッドレターキューに入れる
 */
const handleError = (message) => {
  console.error(message)
  throw new Error(message)
}

/**
 * ComfyUI APIを呼び出す
 */
const fetchComfyuiApi = async (path, method, body) => {
  const comfyUiUrl = await getRunningComfyUiUrl()

  const res = await fetch(`${comfyUiUrl}${path}`, {
    method,
    headers: API_HEADERS,
    body: body ? JSON.stringify(body) : undefined
  })

  const json = await res.json()
  const jsonStr = JSON.stringify(json, null, 2)

  if (!res.ok) {
    handleError(`[${method} ${path}] response is not OK: ${jsonStr}`)
  }
  console.log(`[${method} ${path}] response: ${jsonStr}`)

  return json
}

/**
 * DynamoDBからジョブを取得
 */
const findGenerationJob = async (workflowJobId) => {
  const ddbRes = await ddb.send(new GetItemCommand({
    TableName: DYNAMODB_GENERATION_JOB_TABLE_NAME,
    Key: {
      workflow_job_id: { S: workflowJobId },
    },
  }))

  return ddbRes.Item
}

/**
 * ジョブを実行するかどうかを判断
 */
const judgeShouldExecute = async (workflowJobId) => {
  const generationJobItem = await findGenerationJob(workflowJobId)

  if (!generationJobItem) return false

  const now = Math.floor(Date.now() / 1000)
  const ttl = generationJobItem.ttl?.N ? Number(generationJobItem.ttl.N) : 0

  if (now > ttl) return false

  return true
}

export const handler = async (event) => {
  console.log("SQS event:", JSON.stringify(event, null, 2))

  // eventからパラメータを取得
  const message = event.Records[0]
  const body = JSON.parse(message.body)
  const workflowJobId = body.workflowJobId
  if (!workflowJobId) {
    handleError("Property workflowJobId not found in event body")
  }
  const prompt = body.prompt
  if (!prompt) {
    handleError("Property prompt not found in event body")
  }

  // ジョブを実行するかどうかを判断
  const shouldExecute = await judgeShouldExecute(workflowJobId)
  if (!shouldExecute) {
    console.log("Generation job should not be executed, skipping")
    return
  }

  // dynamodbのcomfyui_last_access_atを更新
  await ddb.send(new PutItemCommand({
    TableName: DYNAMODB_COMFYUI_LAST_ACCESS_AT_TABLE_NAME,
    Item: {
      id: { N: 0 },
      last_access_at: { S: new Date().toISOString() },
    },
  }))

  // ComfyUIにプロンプトを投げる
  const res = await fetchComfyuiApi("/prompt", "POST", {
    client_id: crypto.randomUUID(),
    prompt: body.prompt
  })
  const promptId = res.prompt_id
  if (!promptId) {
    handleError(
      `Property promptId not found in ComfyUI [GET /prompt] response: workflowJobId=${workflowJobId}`
    )
  }

  // ポーリングして完了するまで待つ(完了前に次のキューが実行されてしまうのを防ぐため)
  for (let i = 0; i < MAX_POLL_COUNT; i++) {
    const shouldExecute = await judgeShouldExecute(workflowJobId)

    // shouldExecuteがfalseになった場合は止める
    if (!shouldExecute) {
      await Promise.all([
        fetchComfyuiApi("/interrupt", "POST", {
          prompt_id: promptId
        }),
        fetchComfyuiApi("/queue", "POST", {
          delete: [promptId]
        })
      ])
      return
    }

    // ComfyUIのプロンプト実行結果を取得
    const res = await fetchComfyuiApi(`/history/${promptId}`, "GET")
    const status = res[promptId]?.status

    if (status) {
      if (status.status_str === "success") {
        console.log(`Prompt completed: workflowJobId=${workflowJobId}`)
        return
      }

      handleError(`Prompt failed in ComfyUI: workflowJobId=${workflowJobId}`)
      return
    }

    await new Promise((resolve) => setTimeout(resolve, POLL_INTERVAL))
  }

  console.error(
    "Prompt not completed:",
    JSON.stringify({ workflowJobId }, null, 2)
  )
  throw new Error(`Prompt not completed: workflowJobId=${workflowJobId}`)
}
