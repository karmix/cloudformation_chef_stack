# WIP...don't judge

Documentation to come

## Generating Chef Admin/Org Keys

Run the following and place `.pub` contents (newlines as `\n`) in the stack-parameters.json:

```
openssl genrsa -out chef-admin.pem 2048
openssl rsa -in chef-admin.pem -pubout > chef-admin.pub

openssl genrsa -out validator.pem 2048
openssl rsa -in validator.pem -pubout > validator.pub
```
