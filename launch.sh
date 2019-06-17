export AWS_PROFILE=chef-engineering
MYBUCKET=jerry-cf-testing
MYID=jerry-cf

aws s3 sync . s3://${MYBUCKET}/ --exclude "*" --include "*.yaml" --include "files/*"
aws cloudformation validate-template --template-url https://s3.amazonaws.com/${MYBUCKET}/main.yaml
aws cloudformation create-stack --stack-name ${MYID}-chef-stack \
                                --template-url https://s3.amazonaws.com/${MYBUCKET}/main.yaml \
                                --capabilities CAPABILITY_IAM  \
                                --parameters file://stack_parameters.json \
                                --on-failure DO_NOTHING  \

printf "Creating stack"
while true; do
  printf '.'
  STACK_STATUS="$(aws cloudformation describe-stacks --stack-name ${MYID}-chef-stack | jq -r '.Stacks[0].StackStatus')"
  # TODO: Combine these calls and parse...warning...JSON has `\n`'s
  STACK_STATUS_REASON="$(aws cloudformation describe-stacks --stack-name ${MYID}-chef-stack | jq -r '.Stacks[0].StackStatusReason')"
  if [ "${STACK_STATUS}" != 'CREATE_IN_PROGRESS' ]; then
    echo 'DONE'
    echo "RESULT: ${STACK_STATUS}"
    echo "REASON: ${STACK_STATUS_REASON}"
    break
  fi
  sleep 1
done
