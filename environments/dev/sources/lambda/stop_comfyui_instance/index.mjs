import { DynamoDBClient, GetItemCommand } from '@aws-sdk/client-dynamodb'
import { EC2Client, DescribeInstancesCommand, StopInstancesCommand } from '@aws-sdk/client-ec2'

const DYNAMODB_COMFYUI_LAST_ACCESS_AT_TABLE_NAME = process.env.DYNAMODB_COMFYUI_LAST_ACCESS_AT_TABLE_NAME
const EC2_INSTANCE_ID = process.env.EC2_INSTANCE_ID
const IDLE_THRESHOLD_MS = Number(process.env.IDLE_THRESHOLD_MS ?? 10) * 60 * 1000

const ddb = new DynamoDBClient({})
const ec2 = new EC2Client({})

export const handler = async () => {
  // 環境変数が設定されていない場合はエラーを返す
  if (!DYNAMODB_COMFYUI_LAST_ACCESS_AT_TABLE_NAME) {
    throw new Error('DYNAMODB_COMFYUI_LAST_ACCESS_AT_TABLE_NAME is not set')
  }
  if (!EC2_INSTANCE_ID) {
    throw new Error('EC2_INSTANCE_ID is not set')
  }
  if (IDLE_THRESHOLD_MS === null) {
    throw new Error('IDLE_THRESHOLD_MS is not set')
  }

  // dynamodbから最終アクセス日時を取得
  const ddbRes = await ddb.send(new GetItemCommand({
    TableName: DYNAMODB_COMFYUI_LAST_ACCESS_AT_TABLE_NAME,
    Key: {
      id: { N: "0" },
    },
    ConsistentRead: true,
    ProjectionExpression: 'last_access_at',
  }))
  const lastAccessAt = ddbRes.Item?.last_access_at?.S
  if (!lastAccessAt) {
    throw new Error('last_access_at is not found')
  }

  // EC2インスタンスの状態を取得
  const ec2Res = await ec2.send(new DescribeInstancesCommand({
    InstanceIds: [EC2_INSTANCE_ID],
  }))
  const instance = ec2Res.Reservations?.[0]?.Instances?.[0]
  const instanceState = instance?.State?.Name
  if (!instanceState) {
    throw new Error('Could not get instance state')
  }

  // 最終アクセス時刻から現在時刻の差を取得
  const lastAccessAtDate = new Date(lastAccessAt)
  const now = new Date()
  const diffMs = now.getTime() - lastAccessAtDate.getTime()

  // インスタンスがrunning & 最終アクセス時刻からIDLE_THRESHOLD_MS以上経過している場合はインスタンスを停止
  if (instanceState === 'running' && diffMs > IDLE_THRESHOLD_MS) {
    await ec2.send(new StopInstancesCommand({
      InstanceIds: [EC2_INSTANCE_ID],
    }))

    console.log(`stopped instance: (instanceState: ${instanceState}, lastAccessAt: ${lastAccessAt}, stoppedAt: ${now.toISOString()})`)
    return
  }

  console.log(`skipped: (instanceState: ${instanceState}, lastAccessAt: ${lastAccessAt}, stoppedAt: ${now.toISOString()})`)
}
