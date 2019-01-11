pipeline {
  agent {
    label 'x86&&macOS&&Apps'
  }
  environment {
    VIEW = 'xvf3510'
    REPO = 'lib_mic_array'
  }
  post {
    success {
      updateViewFiles()
    }
  }
}
