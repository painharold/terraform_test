def addParametersToList() {

    def pipelineParametersList = []
    def actions = ['apply', 'destroy']
    def regions = ['eu-central-1', 'eu-north-1', 'eu-west-1', 'ca-central-1', 'us-east-1']
    def cidrBlocks = ['10.0.0.0/16', '172.31.0.0/16', '192.168.0.0/20']

    pipelineParametersList.add(
            choice(name: 'Action', choices: actions, description: getParamsDescription('Deploy Or Destroy'))
    )

    pipelineParametersList.add(
            choice(name: 'Region', choices: regions, description: getParamsDescription('Choose Region To Deploy'))
    )

    pipelineParametersList.add(
            choice(name: 'VPC_Cidr', choices: cidrBlocks, description: getParamsDescription('Choose Cidr Block'))
    )

    return pipelineParametersList
}

pipeline {
    options {
        ansiColor('xterm')
        timestamps()
        timeout(time: 1, unit: 'HOURS')
    }
    agent none

    stages {
        stage('Update Pipeline') {
            steps {
                script {
                    println('------------------ Stage: Update pipeline ------------------')
                    def parametersList = addParametersToList()
                    properties([parameters(parametersList)])
                    if (params.UpdatePipeline.toBoolean()) {
                        currentBuild.description = 'Updating pipeline'
                        currentBuild.getRawBuild().getExecutor().interrupt(Result.SUCCESS)
                        // force stop build with success
                        sleep(1)
                    } else {
                        currentBuild.description = "Deploy to ${params.Region}"
                    }
                    println('------------------ Pipeline was successfully updated ------------------')
                }
            }
        }
        stage('Deploy') {
            steps {
                script {
                    println("------------------ Stage: Deploy to AWS in ${params.Region} ------------------")
                    sh """
                        terraform init
                        terraform apply -var="region=${params.Region}" -var="cidr_block=${params.VPC_Cidr}" --auto-approve
                    """
                    println('------------------ Deployment was successfully completed ------------------')
                }
            }
        }
        stage('Destroy') {
            steps {
                script {
                    println('------------------ Stage: Destroy deployment ------------------')
                    sh """
                        terraform init
                        terraform destroy --auto-approve
                    """
                    println('------------------ Destroy destruction was successfully complete ------------------')
                }
            }
        }
    }
}