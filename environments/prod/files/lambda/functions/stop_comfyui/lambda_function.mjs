import { DynamoDBClient, GetItemCommand } from '@aws-sdk/client-dynamodb'
import { EC2Client, DescribeInstancesCommand, StopInstancesCommand } from '@aws-sdk/client-ec2'

export const handler = async () => {
  const REGION = process.env.AWS_REGION
  const COMFYUI_INSTANCE_ID = process.env.COMFYUI_INSTANCE_ID
  const COMFYUI_INSTANCE_STATUS_DYNAMODB_TABLE_NAME = process.env.COMFYUI_INSTANCE_STATUS_DYNAMODB_TABLE_NAME
  const COMFYUI_INSTANCE_STATUS_DYNAMODB_ITEM_ID = Number(process.env.COMFYUI_INSTANCE_STATUS_DYNAMODB_ITEM_ID ?? 0)
  const IDLE_THRESHOLD_MS = Number(process.env.IDLE_THRESHOLD_MINUTES ?? 10) * 60 * 1000

  // dynamodbからデータを取得
  const ddb = new DynamoDBClient({
    region: REGION,
  })
  const ddbRes = await ddb.send(new GetItemCommand({
    TableName: COMFYUI_INSTANCE_STATUS_DYNAMODB_TABLE_NAME,
    Key: {
      id: { N: COMFYUI_INSTANCE_STATUS_DYNAMODB_ITEM_ID },
    },
    ConsistentRead: true,
    ProjectionExpression: 'last_access_at',
  }))
  const lastAccessAt = ddbRes.Item?.last_access_at?.S
  if (!lastAccessAt) {
    console.log('last_access_at is not found')
    return
  }

  // EC2インスタンスの状態を取得
  const ec2 = new EC2Client({
    region: REGION,
  })
  const ec2Res = await ec2.send(new DescribeInstancesCommand({
    InstanceIds: [COMFYUI_INSTANCE_ID],
  }))
  const instance = ec2Res.Reservations?.[0]?.Instances?.[0]
  const instanceState = instance?.State?.Name

  // 最終アクセス時刻から現在時刻の差を取得
  const lastAccessAtDate = new Date(lastAccessAt)
  const now = new Date()
  const diffMs = now.getTime() - lastAccessAtDate.getTime()
  
  // インスタンスがrunning & 最終アクセス時刻からIDLE_THRESHOLD_MS以上経過している場合はインスタンスを停止
  if (instanceState === 'running' && diffMs > IDLE_THRESHOLD_MS) {
    await ec2.send(new StopInstancesCommand({
      InstanceIds: [COMFYUI_INSTANCE_ID],
    }))

    console.log(`stopped instance: (instanceState: ${instanceState}, lastAccessAt: ${lastAccessAt}, stoppedAt: ${now.toISOString()})`)
    return
  }

  console.log(`skipped: (instanceState: ${instanceState}, lastAccessAt: ${lastAccessAt}, stoppedAt: ${now.toISOString()})`)
}
