MYID=jerry-cf

SECRET_BUCKET="$(aws s3 ls | grep $MYID-chef-stack-chefstacksecretsbucket | cut -d' ' -f3)"
if [ $SECRET_BUCKET ]; then
  printf "Deleting bucket..."
  aws s3 rb s3://$SECRET_BUCKET --force >/dev/null 2>&1
  echo "DONE"
fi

printf "Deleting stack"
aws cloudformation delete-stack --stack-name ${MYID}-chef-stack
while true; do
  printf '.'
  if ! aws cloudformation describe-stacks --stack-name $MYID-chef-stack >/dev/null 2>&1; then
    echo "DONE"
    break
  fi
  sleep 1
done
