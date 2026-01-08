pipeline {
  agent any

  parameters {
    choice choices: ['apply', 'destroy'], name: 'DEPLOY'
    string defaultValue: 'DEJI', name: 'RUNNER'
  }

  environment {
    PATH = "${PATH}:${getTerraformPath()}"
  }

  stages {
    stage('Terraform Plan') {
      steps {
        slackSend (color: '#fffb00ff', message: "${params.RUNNER} STARTED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
        sh """
        terraform init
        terraform validate
        terraform plan -out=tfplan -input=false
        """
      }
    }

    stage('Terraform Apply/Destroy'){
      steps {
        script {
          if (params.DEPLOY == 'apply') {
            sh "terraform apply -input=false tfplan" 
            slackSend (color: '#00ff2aff', message: "FINISHED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})")
          }
          else if (params.DEPLOY == 'destroy') {
            sh "terraform destroy -auto-approve"
            slackSend (color: '#ff000dff', message: "DESTROYED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL}). Initiated by ${params.RUNNER}")
          }
        }
      }
    }
    // stage('Terraform Destroy'){
    //   when {
    //     expression { params.DESTROY }
    //   }
    //   steps {
    //     sh "terraform destroy -auto-approve"
    //     slackSend (color: '#ff000dff', message: "DESTROYED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL}). Initiated by ${params.RUNNER}")
    //   }
    // }
  }
}

def getTerraformPath() {
  def tfHome = tool name: 'terraform-14', type: 'terraform'
  return tfHome
}