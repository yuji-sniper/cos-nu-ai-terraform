import { createClient } from "@supabase/supabase-js"
import { uuidv7 } from "uuidv7"
import { SSMClient, GetParameterCommand } from "@aws-sdk/client-ssm"
import { S3Client, DeleteObjectCommand } from "@aws-sdk/client-s3"

const SSM_PARAMETER_NAME_SUPABASE_URL = process.env.SSM_PARAMETER_NAME_SUPABASE_URL
const SSM_PARAMETER_NAME_SUPABASE_SERVICE_ROLE_KEY = process.env.SSM_PARAMETER_NAME_SUPABASE_SERVICE_ROLE_KEY
const TABLE_NAME_WORKFLOW_JOBS = "workflow_jobs"
const TABLE_NAME_WORKFLOW_JOB_ARTIFACTS = "workflow_job_artifacts"
const ERROR_CODE_FOREIGN_KEY_VIOLATION = "23503"
const WORKFLOW_JOB_ID_FOREIGN_KEY = "workflow_job_artifacts_workflow_job_id_workflow_jobs_id_fk"

const ssm = new SSMClient({})
const s3 = new S3Client({})

const handleError = (message) => {
  console.error(message)
  throw new Error(message)
}

export const handler = async (event) => {
  // S3に保存された画像のパスを取得
  const key = event.Records[0].s3.object.key
  const bucket = event.Records[0].s3.bucket.name

  // もしキーがディレクトリパスで終わっていたらスキップ
  if (key.endsWith("/")) {
    console.log(`Directory path found: ${key}. Skip.`)
    return
  }

  // SSM ParameterからSupabase認証情報を取得
  const supabaseUrlParameter = await ssm.send(new GetParameterCommand({
    Name: SSM_PARAMETER_NAME_SUPABASE_URL,
    WithDecryption: true
  }))
  const supabaseUrl = supabaseUrlParameter.Parameter?.Value
  const supabaseServiceRoleKeyParameter = await ssm.send(new GetParameterCommand({
    Name: SSM_PARAMETER_NAME_SUPABASE_SERVICE_ROLE_KEY,
    WithDecryption: true
  }))
  const supabaseServiceRoleKey = supabaseServiceRoleKeyParameter.Parameter?.Value
  if (!supabaseUrl || !supabaseServiceRoleKey) {
    handleError("Supabase URL or service role key is not set")
  }

  // Supabaseクライアントの作成
  const supabase = createClient(supabaseUrl, supabaseServiceRoleKey)


  // パス(outputs/{userStorageKey}/{workflowJobId}/{fileName})からworkflowJobIdを取得
  const splitted = key.split("/")
  const workflowJobId = splitted[2]
  if (!workflowJobId) {
    handleError(`Unexpected key format: ${key}`)
  }

  // workflowJobIdとパスからworkflowJobArtifactを作成(supabaseのAPIを使用)
  const { error: artifactError } = await supabase.from(TABLE_NAME_WORKFLOW_JOB_ARTIFACTS).insert({
    id: uuidv7(),
    workflow_job_id: workflowJobId,
    file_path: key
  })
  if (artifactError) {
    // 外部キー違反の場合はworkflow_jobsレコードが削除されているとみなし、オブジェクトを削除
    const isFkViolation =
      artifactError.code === ERROR_CODE_FOREIGN_KEY_VIOLATION &&
      artifactError.constraint === WORKFLOW_JOB_ID_FOREIGN_KEY
    if (isFkViolation) {
      await s3.send(new DeleteObjectCommand({
        Bucket: bucket,
        Key: key
      }))
      console.log(`${TABLE_NAME_WORKFLOW_JOBS} record is deleted, so delete the object from S3; skip. workflowJobId=${workflowJobId}`)
      return
    } else {
      handleError(`Failed to insert ${TABLE_NAME_WORKFLOW_JOB_ARTIFACTS} record: ${artifactError.message}`)
    }
  }

  console.log("completed")
}
