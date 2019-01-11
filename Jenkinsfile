pipeline {
  agent {
    label 'x86&&macOS&&Apps'
  }
  environment {
    VIEW = 'mic_array'
    REPO = 'lib_mic_array'
  }
  options {
    skipDefaultCheckout()
  }
  stages {
    stage('Get View') {
      steps {
        prepareAppsSandbox("${VIEW}", "${REPO}")
      }
    }
    stage('Library Checks') {
      steps {
        xcoreLibraryChecks("${REPO}")
      }
    }
  }
  post {
    success {
      updateViewfiles()
    }
    cleanup {
      cleanWs()
    }
  }
}
