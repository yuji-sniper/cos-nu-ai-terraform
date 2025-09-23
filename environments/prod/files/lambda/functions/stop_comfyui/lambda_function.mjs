

export const handler = async (event, context) => {

  // DynamoDBのテーブルからデータを取得

  // last_access_atが20分以上経過している場合はEC2インスタンスを停止

  return 'ok'
};
