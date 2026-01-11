import { createClient } from "@supabase/supabase-js"
import { SSMClient, GetParameterCommand } from "@aws-sdk/client-ssm"
import { DynamoDBClient, UpdateItemCommand } from "@aws-sdk/client-dynamodb"

const SSM_PARAMETER_NAME_SUPABASE_URL = process.env.SSM_PARAMETER_NAME_SUPABASE_URL
const SSM_PARAMETER_NAME_SUPABASE_SERVICE_ROLE_KEY = process.env.SSM_PARAMETER_NAME_SUPABASE_SERVICE_ROLE_KEY
const DYNAMODB_GENERATION_JOB_TABLE_NAME = process.env.DYNAMODB_GENERATION_JOB_TABLE_NAME
const TOKEN_RECOVERY_AMOUNT = parseInt(process.env.TOKEN_RECOVERY_AMOUNT || "1")

const ssm = new SSMClient({})
const ddb = new DynamoDBClient({})

let supabaseClient = null

/**
 * Get Supabase client (lazy initialization)
 */
async function getSupabaseClient() {
  if (supabaseClient) return supabaseClient

  const [urlParam, keyParam] = await Promise.all([
    ssm.send(new GetParameterCommand({
      Name: SSM_PARAMETER_NAME_SUPABASE_URL,
      WithDecryption: true
    })),
    ssm.send(new GetParameterCommand({
      Name: SSM_PARAMETER_NAME_SUPABASE_SERVICE_ROLE_KEY,
      WithDecryption: true
    }))
  ])

  const supabaseUrl = urlParam.Parameter?.Value
  const supabaseServiceRoleKey = keyParam.Parameter?.Value

  if (!supabaseUrl || !supabaseServiceRoleKey) {
    throw new Error("Supabase credentials not found in SSM")
  }

  supabaseClient = createClient(supabaseUrl, supabaseServiceRoleKey)
  return supabaseClient
}

/**
 * Get user_id from workflow_job_id
 */
async function getUserIdFromWorkflowJobId(supabase, workflowJobId) {
  const { data, error } = await supabase
    .from('workflow_jobs')
    .select('user_id')
    .eq('id', workflowJobId)
    .single()

  if (error) {
    throw new Error(`Failed to query workflow_jobs: ${error.message}`)
  }

  return data.user_id
}

/**
 * Recover tokens for user
 */
async function recoverTokens(supabase, userId, amount) {
  const { error } = await supabase.rpc('increment_users_token_balance', {
    user_id_param: userId,
    amount: amount
  })

  if (error) {
    throw new Error(`Failed to recover tokens: ${error.message}`)
  }

  console.info(JSON.stringify({
    message: 'Token recovery successful',
    userId,
    amount
  }))
}

/**
 * Mark recovery as completed in DynamoDB
 */
async function markRecoveryCompleted(workflowJobId) {
  try {
    await ddb.send(new UpdateItemCommand({
      TableName: DYNAMODB_GENERATION_JOB_TABLE_NAME,
      Key: {
        workflow_job_id: { S: workflowJobId }
      },
      UpdateExpression: "SET tokens_recovered = :true",
      ConditionExpression: "attribute_not_exists(tokens_recovered) OR tokens_recovered = :false",
      ExpressionAttributeValues: {
        ":true": { BOOL: true },
        ":false": { BOOL: false },
      }
    }))
  } catch (error) {
    if (error.name === 'ConditionalCheckFailedException') {
      console.info(JSON.stringify({
        message: 'Tokens already recovered (idempotency check)',
        workflowJobId
      }))
      return false
    }
    throw error
  }
  return true
}

/**
 * Process a single DynamoDB Stream record
 */
async function processRecord(supabase, record) {
  console.info(JSON.stringify({
    message: 'Processing DynamoDB Stream record',
    eventName: record.eventName,
    timestamp: new Date().toISOString()
  }))

  // Only process MODIFY events
  if (record.eventName !== 'MODIFY') {
    console.info('Skipping non-MODIFY event')
    return
  }

  const newImage = record.dynamodb.NewImage
  const oldImage = record.dynamodb.OldImage

  // Check if this record should trigger recovery
  const jobFailed = newImage?.job_failed?.BOOL === true
  const wasAlreadyFailed = oldImage?.job_failed?.BOOL === true
  const tokensRecovered = newImage?.tokens_recovered?.BOOL === true

  if (!jobFailed || wasAlreadyFailed || tokensRecovered) {
    console.info(JSON.stringify({
      message: 'Skipping record',
      reason: !jobFailed ? 'job_not_failed' :
              wasAlreadyFailed ? 'already_failed' : 'already_recovered',
      timestamp: new Date().toISOString()
    }))
    return
  }

  const workflowJobId = newImage.workflow_job_id.S

  console.info(JSON.stringify({
    message: 'Starting token recovery',
    workflowJobId,
    timestamp: new Date().toISOString()
  }))

  // Get user_id from Supabase
  const userId = await getUserIdFromWorkflowJobId(supabase, workflowJobId)

  if (!userId) {
    console.info(JSON.stringify({
      message: 'User not found, skipping token recovery',
      workflowJobId,
      timestamp: new Date().toISOString()
    }))

    // Mark as attempted to avoid infinite retries
    await markRecoveryCompleted(workflowJobId)
    return
  }

  // Recover tokens
  await recoverTokens(supabase, userId, TOKEN_RECOVERY_AMOUNT)

  // Mark as recovered
  const marked = await markRecoveryCompleted(workflowJobId)

  if (marked) {
    console.info(JSON.stringify({
      message: 'Token recovery completed',
      workflowJobId,
      userId,
      amount: TOKEN_RECOVERY_AMOUNT,
    }))
  }
}

/**
 * Lambda handler
 */
export const handler = async (event) => {
  console.info(JSON.stringify({
    message: 'DynamoDB Stream event received',
    recordCount: event.Records.length
  }))

  const supabase = await getSupabaseClient()

  for (const record of event.Records) {
    try {
      await processRecord(supabase, record)
    } catch (error) {
      console.error(JSON.stringify({
        message: 'Failed to process record',
        error: error.message,
        stack: error.stack,
        record: JSON.stringify(record),
      }))

      // Rethrow to trigger Lambda retry
      throw error
    }
  }

  console.info(JSON.stringify({
    message: 'Batch processing completed'
  }))
}
