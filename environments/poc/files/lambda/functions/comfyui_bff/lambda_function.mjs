import { EC2Client, DescribeInstancesCommand } from '@aws-sdk/client-ec2'

const REGION = process.env.AWS_REGION
const COMFYUI_INSTANCE_ID = process.env.COMFYUI_INSTANCE_ID
const COMFYUI_PORT = 8188

/**
 * インスタンスの情報を取得
 */
async function describeInstance(ec2Client) {
  const ec2Res = await ec2Client.send(new DescribeInstancesCommand({
    InstanceIds: [COMFYUI_INSTANCE_ID],
  }))
  return ec2Res.Reservations?.[0]?.Instances?.[0]
}

/**
 * URLを生成
 */
function buildUrl(privateIp, path, queryString) {
  const url = new URL(`http://${privateIp}:${COMFYUI_PORT}${path}`)
  if (queryString) {
    url.search = queryString
  }
  return url.toString()
}

/**
 * リクエストボディを生成
 */
function buildBody(method, body) {
  if (method === 'GET' || method === 'HEAD' || !body) {
    return undefined
  }

  const obj = JSON.parse(body)

  return JSON.stringify(obj)
}

/**
 * ComfyUIにAPIリクエスト
 */
async function fetchComfyuiApi(privateIp, event) {
  const url = buildUrl(privateIp, event.requestContext.http.path, event.rawQueryString)
  const method = event.requestContext.http.method
  const headers = {
    'Content-Type': 'application/json',
  }
  const body = buildBody(method, event.body)

  const response = await fetch(url, {method, headers, body})

  return response
}

/**
 * ハンドラー
 */
export const handler = async (event) => {
  console.log(event)

  if (!COMFYUI_INSTANCE_ID) {
    return {
      statusCode: 500,
      body: JSON.stringify({ message: "comfyui instance id is not set" }),
    }
  }

  const ec2Client = new EC2Client({
    region: REGION,
  })

  try {
    // インスタンスの情報を取得
    const instance = await describeInstance(ec2Client)
  
    // インスタンスのプライベートIPを取得
    const privateIp = instance?.PrivateIpAddress
    if (!privateIp) {
      throw new Error("private ip is not found")
    }
  
    // ComfyUIにAPIリクエスト
    const comfyuiRes = await fetchComfyuiApi(privateIp, event)
  
    return {
      statusCode: comfyuiRes.status,
      headers: comfyuiRes.headers,
      body: await comfyuiRes.text(),
    }
  } catch (error) {
    console.error(error)
    return {
      statusCode: 500,
      body: JSON.stringify({ message: "failed to request to comfyui" }),
    }
  }
}
