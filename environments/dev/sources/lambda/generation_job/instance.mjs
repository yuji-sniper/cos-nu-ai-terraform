import { EC2Client, DescribeInstancesCommand, StartInstancesCommand } from '@aws-sdk/client-ec2'

const INSTANCE_ID = process.env.INSTANCE_ID
const INSTANCE_READY_TIMEOUT_MS = 3 * 60 * 1000
const INSTANCE_STATE_POLL_INTERVAL_MS = 5000
const COMFYUI_READY_TIMEOUT_MS = 2 * 60 * 1000
const COMFYUI_READY_POLL_INTERVAL_MS = 5000

const ec2 = new EC2Client({})

/**
 * インスタンスの情報を取得
 */
async function describeInstance() {
  const ec2Res = await ec2.send(new DescribeInstancesCommand({
    InstanceIds: [INSTANCE_ID],
  }))
  return ec2Res.Reservations?.[0]?.Instances?.[0]
}

/**
 * インスタンスを起動
 */
async function startInstance() {
  await ec2.send(new StartInstancesCommand({
    InstanceIds: [INSTANCE_ID],
  }))
}

/**
 * インスタンスが引数のステータスになるまで待つ
 */
async function waitForInstanceState(wanted) {
  const startTime = Date.now()

  while (Date.now() - startTime < INSTANCE_READY_TIMEOUT_MS) {
    const instance = await describeInstance()
    if (instance?.State?.Name === wanted) {
      return instance
    }

    await new Promise(resolve => setTimeout(resolve, INSTANCE_STATE_POLL_INTERVAL_MS))
  }

  throw new Error(`[waitForInstanceState] timeout: (wanted: ${wanted})`)
}

/**
 * runningなインスタンスを取得
 * *必要に応じて起動し、runningになるまで待つ
 */
async function getRunningInstance() {
  const instance = await describeInstance()
  if (!instance) {
    throw new Error("instance is not found")
  }

  switch (instance?.State?.Name) {
    case 'stopping':
      console.log("[getRunningInstance] instance is stopping, waiting for stopped")
      await waitForInstanceState('stopped')
      console.log("[getRunningInstance] instance is stopped, starting instance")
      await startInstance()
      return await waitForInstanceState('running')
    case 'stopped':
      console.log("[getRunningInstance] instance is stopped, starting instance")
      await startInstance()
      return await waitForInstanceState('running')
    case 'pending':
      console.log("[getRunningInstance] instance is pending, waiting for running")
      return await waitForInstanceState('running')
    case 'running':
      return instance
    default:
      throw new Error(`[getRunningInstance] instance is in unknown state: (state: ${instance?.State?.Name})`)
  }
}

export async function getRunningComfyUiUrl() {
  const instance = await getRunningInstance()

  const privateIp = instance.PrivateIpAddress
  if (!privateIp) {
    throw new Error("private ip is not found")
  }

  const comfyUiUrl = `http://${privateIp}:8188`

  const startTime = Date.now()
  while (Date.now() - startTime < COMFYUI_READY_TIMEOUT_MS) {
    const res = await fetch(`${comfyUiUrl}/`, {
      method: 'GET',
      headers: {
        'Content-Type': 'application/json',
        'Range': 'bytes=0-0',
      },
    })
    if (res.status === 206 || res.status === 200) {
      return comfyUiUrl
    }

    await new Promise(resolve => setTimeout(resolve, COMFYUI_READY_POLL_INTERVAL_MS))
  }

  throw new Error("[getRunningComfyUiUrl] timeout")
}
