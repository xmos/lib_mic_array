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
  triggers {
    /* Trigger this Pipeline on changes to the repos dependencies
     *
     * If this Pipeline is running in a pull request, the triggers are set
     * on the base branch the PR is set to merge in to.
     *
     * Otherwise the triggers are set on the branch of a matching name to the
     * one this Pipeline is on.
     */
    upstream(
      upstreamProjects:
        (env.JOB_NAME.contains('PR-') ?
          "../lib_dsp/${env.CHANGE_TARGET}," +
          "../lib_i2c/${env.CHANGE_TARGET}," +
          "../lib_i2s/${env.CHANGE_TARGET}," +
          "../lib_logging/${env.CHANGE_TARGET}," +
          "../lib_mic_array_board_support/${env.CHANGE_TARGET}," +
          "../lib_xassert/${env.CHANGE_TARGET}," +
          "../tools_released/${env.CHANGE_TARGET}," +
          "../tools_xmostest/${env.CHANGE_TARGET}," +
          "../xdoc_released/${env.CHANGE_TARGET}"
        :
          "../lib_dsp/${env.BRANCH_NAME}," +
          "../lib_i2c/${env.BRANCH_NAME}," +
          "../lib_i2s/${env.BRANCH_NAME}," +
          "../lib_logging/${env.BRANCH_NAME}," +
          "../lib_mic_array_board_support/${env.BRANCH_NAME}," +
          "../lib_xassert/${env.BRANCH_NAME}," +
          "../tools_released/${env.BRANCH_NAME}," +
          "../tools_xmostest/${env.BRANCH_NAME}," +
          "../xdoc_released/${env.BRANCH_NAME}"),
      threshold: hudson.model.Result.SUCCESS
    )
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
    stage('Patch tools') {
      steps {
        dir('tools_released/xwaf_patch') {
          viewEnv() {
            sh './xpatch'
          }
        }
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
    stage('Tests') {
      steps {
        runXmostest("${REPO}", 'tests')
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
