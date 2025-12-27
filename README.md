## 基本操作

### 各環境のディレクトリに移動
```sh
$ cd environments/{環境}
```

### makefileのシンボリックリングを貼る
```sh
$ ln -sf ../../makefile makefile
```

### 各環境のディレクトリで共通設定ファイルのシンボリックリンクを貼る
```sh
$ make ln
```

### 各種ファイル作成
- backend.config
- locals.tf
- main.tf
- terraform.tfvars
- terraform.tfvars.example
- variable.tf

### init
```sh
$ make init
```

### plan、apply
```sh
$ terraform plan
$ terraform apply
```

### gpg復号
```sh
$ echo "{output出力された暗号文字列}" | base64 -d | gpg -r naoto-yoshimura
```
