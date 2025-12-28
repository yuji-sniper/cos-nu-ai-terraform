// TODO: pocに合わせて修正する
import { EC2Client, DescribeInstancesCommand, StartInstancesCommand } from '@aws-sdk/client-ec2'
import { DynamoDBClient, PutItemCommand } from '@aws-sdk/client-dynamodb'

const REGION = process.env.AWS_REGION
const COMFYUI_INSTANCE_ID = process.env.COMFYUI_INSTANCE_ID
const COMFYUI_INSTANCE_STATUS_DYNAMODB_TABLE_NAME = process.env.COMFYUI_INSTANCE_STATUS_DYNAMODB_TABLE_NAME
const COMFYUI_INSTANCE_STATUS_DYNAMODB_ITEM_ID = Number(process.env.COMFYUI_INSTANCE_STATUS_DYNAMODB_ITEM_ID ?? 0)
const INSTANCE_READY_TIMEOUT_MS = Number(process.env.INSTANCE_READY_TIMEOUT_MINUTES ?? 3) * 60 * 1000
const COMFYUI_PORT = 8188

/**
 * インスタンスの情報を取得
 */
async function describeInstance(ec2) {
  const ec2Res = await ec2.send(new DescribeInstancesCommand({
    InstanceIds: [COMFYUI_INSTANCE_ID],
  }))
  return ec2Res.Reservations?.[0]?.Instances?.[0]
}

/**
 * インスタンスを起動
 */
async function startInstance(ec2) {
  await ec2.send(new StartInstancesCommand({
    InstanceIds: [COMFYUI_INSTANCE_ID],
  }))
}

/**
 * インスタンスが引数のステータスになるまで待つ
 */
async function waitForInstanceState(ec2, wanted, timeout) {
  const startTime = Date.now()

  while (Date.now() - startTime < timeout) {
    const instance = await describeInstance(ec2)
    if (instance?.State?.Name === wanted) {
      return instance
    }

    await new Promise(resolve => setTimeout(resolve, 3000))
  }

  throw new Error(`[waitForInstanceState] timeout: (wanted: ${wanted})`)
}

/**
 * インスタンスの状態に応じてrunningになるまで待つ
 */
async function waitForInstanceRunning(ec2, instance) {
  switch (instance?.State?.Name) {
    case 'stopping':
      console.log("[waitForInstanceRunning] instance is stopping, waiting for stopped")
      await waitForInstanceState(ec2, 'stopped', INSTANCE_READY_TIMEOUT_MS)
      console.log("[waitForInstanceRunning] instance is stopped, starting instance")
      await startInstance(ec2)
      return await waitForInstanceState(ec2, 'running', INSTANCE_READY_TIMEOUT_MS)
    case 'stopped':
      console.log("[waitForInstanceRunning] instance is stopped, starting instance")
      await startInstance(ec2)
      return await waitForInstanceState(ec2, 'running', INSTANCE_READY_TIMEOUT_MS)
    case 'pending':
      console.log("[waitForInstanceRunning] instance is pending, waiting for running")
      return await waitForInstanceState(ec2, 'running', INSTANCE_READY_TIMEOUT_MS)
    case 'running':
      return instance
    default:
      throw new Error(`[waitForInstanceRunning] instance is in unknown state: (state: ${instance?.State?.Name})`)
  }
}

/**
 * ComfyUIにリクエストを送信
 */
async function fetchComfyuiApi(privateIp, path, method, body, headers) {
  const response = await fetch(`http://${privateIp}:${COMFYUI_PORT}${path}`, {
    method: method,
    headers: {
      'Content-Type': 'application/json',
      ...headers,
    },
    body: body,
  })

  return response
}

/**
 * ComfyUIが起動するまで待つ
 */
async function waitForComfyuiReady(privateIp, timeout) {
  const startTime = Date.now()

  while (Date.now() - startTime < timeout) {
    const response = await fetchComfyuiApi(
      privateIp,
      '/',
      'GET',
      null,
      { Range: "bytes=0-0" },
    )
    if (response.status === 206 || response.status === 200) {
      return true
    }

    await new Promise(resolve => setTimeout(resolve, 5000))
  }

  throw new Error("[waitForComfyuiReady] timeout")
}

export const handler = async (event) => {
  const ec2 = new EC2Client({
    region: REGION,
  })
  const ddb = new DynamoDBClient({
    region: REGION,
  })

  // インスタンスの情報を取得
  const currentInstance = await describeInstance(ec2)

  // インスタンスがrunningになるまで待機
  const instance = await waitForInstanceRunning(ec2, currentInstance)

  // インスタンスのプライベートIPを取得
  const privateIp = instance?.PrivateIpAddress
  if (!privateIp) {
    throw new Error("private ip is not found")
  }

  // ComfyUIが起動するまで待機
  await waitForComfyuiReady(privateIp, INSTANCE_READY_TIMEOUT_MS)

  // ComfyUIにAPIリクエスト
  const comfyuiRes = await fetchComfyuiApi(privateIp, event.path, event.method, event.body)
  if (!comfyuiRes.ok) {
    return {
      statusCode: 500,
      body: JSON.stringify({ message: "failed to request to comfyui" }),
    }
  }

  // dynamodbのlast_access_atを更新
  await ddb.send(new PutItemCommand({
    TableName: COMFYUI_INSTANCE_STATUS_DYNAMODB_TABLE_NAME,
    Item: {
      id: { N: COMFYUI_INSTANCE_STATUS_DYNAMODB_ITEM_ID },
      last_access_at: { S: new Date().toISOString() },
    },
  }))

  return {
    statusCode: 200,
    headers: {
      'Content-Type': 'application/json',
    },
    body: await comfyuiRes.text(),
  }
}
