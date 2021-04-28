@Library('xmos_jenkins_shared_library@v0.16.2') _
getApproval()

pipeline {
  agent {
    label 'x86_64&&brew'
  }
  environment {
    REPO = 'lib_mic_array'
    VIEW = getViewName(REPO)
  }
  options {
    skipDefaultCheckout()
  }
  stages {
    stage('Get View') {
      steps {
        xcorePrepareSandbox("${VIEW}", "${REPO}")
      }
    }
    stage('Library Checks') {
      steps {
        xcoreLibraryChecks("${REPO}")
      }
    }
    stage('Unit tests') {
      steps {
        dir("${REPO}/tests/unit_tests") {
          viewEnv() {
            runWaf('.')
            runPytest()
          }
        }
      }
    }
    stage('Legacy Tests') {
      steps {
        dir("${REPO}/legacy_tests") {
          viewEnv() {
            // Use requirements.txt in legacy_tests, not lib_mic_array/requirements.txt
            installPipfile(true)
            runPython("./runtests.py --junit-output=${REPO}_tests.xml")
          }
        }
      }
    }
    stage('Build') {
      steps {
        dir("${REPO}") {
          xcoreAllAppsBuild('examples')
          xcoreAllAppNotesBuild('examples')
          runXdoc('${REPO}/doc')
        }
        // Archive all the generated .pdf docs
        archiveArtifacts artifacts: "${REPO}/**/pdf/*.pdf", fingerprint: true, allowEmptyArchive: true
      }
    }
  }
  post {
    success {
      updateViewfiles()
    }
    cleanup {
      xcoreCleanSandbox()
    }
  }
}
