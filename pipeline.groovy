def addParametersToList() {

    def pipelineParametersList = []
    def actions = ['apply', 'destroy']
    def regions = ['eu-central-1', 'eu-north-1', 'eu-west-1', 'ca-central-1', 'us-east-1']
    def cidrBlocks = ['10.0.0.0/16', '172.31.0.0/16', '192.168.0.0/20']

    pipelineParametersList.add(
        choice(name: 'Action', choices: actions, description: 'Deploy or destroy')
    )

    pipelineParametersList.add(
        choice(name: 'Region', choices: regions, description: 'Choose region to deploy')
    )

    pipelineParametersList.add(
        choice(name: 'VPC_Cidr', choices: cidrBlocks, description: 'Choose cidr block')
    )

    pipelineParametersList.add(
        booleanParam(name: 'UpdatePipeline', defaultValue: false, description: 'Update pipeline configuration')
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
                    if (params.UpdatePipeline) {
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
        stage('Git checkout') {
            steps {
                script {
                    println("------------------ Stage: Download repository ------------------")
                    git branch: 'jenkins', credentialsId: 'ssh_git',
                        url: 'git@github.com:painharold/terraform_test.git'
                    println('------------------ Repository was successfully downloaded ------------------')
                }

            }

        }
        stage('Deploy') {
            when {
                expression {
                    params.Action == 'apply'
                }
            }
            steps {
                script {
                    dir('terraform/test_project') {
                        println("------------------ Stage: Deploy to AWS in ${params.Region} ------------------")
                        withCredentials([string(credentialsId: 'key_id', variable: 'AWS_ACCESS_KEY_ID'),
                                 string(credentialsId: 'access_key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                            sh """
                                terraform init
                                terraform apply -var="region=${params.Region}" -var="cidr_block=${params.VPC_Cidr}" --auto-approve
                            """
                        }
                        println('------------------ Deployment was successfully completed ------------------')
                    }
                }
            }
        }
        stage('Destroy') {
            when {
                expression {
                    params.Action == 'destroy'
                }
            }
            steps {
                script {
                    dir('terraform/test_project') {
                        println('------------------ Stage: Destroy deployment ------------------')
                        withCredentials([string(credentialsId: 'key_id', variable: 'AWS_ACCESS_KEY_ID'),
                                 string(credentialsId: 'access_key', variable: 'AWS_SECRET_ACCESS_KEY')]) {
                            sh """
                                terraform init
                                terraform destroy --auto-approve
                            """
                        }
                        println('------------------ Destroy destruction was successfully complete ------------------')
                    }
                }
            }
        }
        cleanWs()
    }
}