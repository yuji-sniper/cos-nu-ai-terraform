import {
  DeleteObjectsCommand,
  ListObjectsV2Command,
  S3Client
} from "@aws-sdk/client-s3"

const s3 = new S3Client({})

const handleError = (message) => {
  console.error(message)
  throw new Error(message)
}

const listAllObjects = async ({ bucket, prefix, userStorageKey }) => {
  const all = []
  let token

  while (true) {
    const res = await s3.send(
      new ListObjectsV2Command({
        Bucket: bucket,
        Prefix: `${prefix}/${userStorageKey}/`,
        ContinuationToken: token
      })
    )

    if (res.Contents?.length) all.push(...res.Contents)

    if (!res.IsTruncated) break
    token = res.NextContinuationToken
    if (!token) break
  }

  return all
}

const deleteKeys = async ({ bucket, keys }) => {
  const chunkSize = 1000
  for (let i = 0; i < keys.length; i += chunkSize) {
    const chunk = keys.slice(i, i + chunkSize)
    if (chunk.length === 0) continue

    await s3.send(
      new DeleteObjectsCommand({
        Bucket: bucket,
        Delete: {
          Objects: chunk.map((Key) => ({ Key })),
          Quiet: true
        }
      })
    )
  }
}

export const handler = async (event) => {
  // eventからbucket名を取得
  const record = event?.Records?.[0] || {}
  const bucket = record?.s3?.bucket?.name
  if (!bucket) {
    console.log("Bucket name not found in event. Skip.")
    return { deleted: 0, total: 0 }
  }

  // keyからprefixとuserStorageKeyを取得
  const key = record.s3.object.key
  const splitted = key.split("/")
  const prefix = splitted[0]
  const userStorageKey = splitted[1]

  // 環境変数からlimitを取得
  const limit = process.env.LIMIT
  if (!limit) {
    handleError("environment variable LIMIT is not set")
  }
  const limitInt = Number.parseInt(limit, 10)
  if (Number.isNaN(limitInt)) {
    handleError("environment variable LIMIT is not a number")
  }
  if (limitInt <= 0) {
    handleError("environment variable LIMIT is not a positive number")
  }

  // S3に保存されたオブジェクトを取得
  const objects = await listAllObjects({ bucket, prefix, userStorageKey })
  const total = objects.length

  // オブジェクト数がlimit以下の場合はスキップ
  if (total <= limit) {
    console.log(
      `No cleanup required. bucket=${bucket} prefix=${prefix} total=${total} max=${limit}`
    )
    return { deleted: 0, total }
  }

  // オブジェクトを古い順にソート
  objects.sort((a, b) => {
    const at = a?.LastModified ? new Date(a.LastModified).getTime() : 0
    const bt = b?.LastModified ? new Date(b.LastModified).getTime() : 0
    return at - bt
  })

  // オブジェクト数がlimitを超えている場合は古いオブジェクトを削除対象として抽出
  const over = total - limit
  const deleteKeysList = objects
    .slice(0, over)
    .map((o) => o.Key)
    .filter(Boolean)

  // 削除対象のオブジェクトがない場合はスキップ
  if (deleteKeysList.length === 0) {
    console.log(
      `Over limit but no deletable keys found. bucket=${bucket} prefix=${prefix} total=${total} max=${limit}`
    )
    return { deleted: 0, total }
  }

  // 削除対象のオブジェクトを削除
  await deleteKeys({ bucket, keys: deleteKeysList })

  console.log(
    `Cleanup done. bucket=${bucket} prefix=${prefix} total=${total} max=${limit} deleted=${deleteKeysList.length}`
  )
  console.log("Deleted keys sample (up to 10):", deleteKeysList.slice(0, 10))

  return { deleted: deleteKeysList.length, total }
}
