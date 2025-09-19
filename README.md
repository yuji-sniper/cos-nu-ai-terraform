### 各環境のディレクトリに移動
```sh
$ cd {環境ディレクトリ}
```

### 各環境のディレクトリで共通設定ファイルのシンボリックリンクを貼る
```sh
$ ln -sf ../../backend.tf backend.tf
$ ln -sf ../../provider.tf provider.tf
$ ln -sf ../../base_locals.tf base_locals.tf
```

### init
```sh
$ terraform init -backend-config=backend.config
```

### plan、apply
```sh
$ terraform plan
$ terraform apply
```

### 秘密鍵 Secret Manager アップロード
バイナリにしてアップロード。
```sh
$ aws secretsmanager create-secret \
    --name {キー名} \
    --secret-binary file://~/.ssh/private.pem
```
取り出し。
```sh
$ aws secretsmanager get-secret-value \
    --secret-id {キー名} \
    --query 'SecretBinary' \
    --output text \
    | base64 -d > private.pem
```
