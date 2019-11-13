@Library('xmos_jenkins_shared_library@develop') _

getApproval()

pipeline {
  agent {
    label 'x86_64&&brew'
  }
  environment {
    REPO = 'lib_mic_array'
    VIEW = "${env.JOB_NAME.contains('PR-') ? REPO+'_'+env.CHANGE_TARGET : REPO+'_'+env.BRANCH_NAME}"
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
          runWaf('.')
          viewEnv() {
            runPytest()
          }
        }
      }
    }
    stage('Legacy Tests') {
      steps {
        dir("${REPO}/legacy_tests") {
          viewEnv() {
            // Use Pipfile in legacy_tests, not lib_mic_array/Pipfile
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
          dir("${REPO}") {
            runXdoc('doc')
          }
        }
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
