// This file relates to internal XMOS infrastructure and should be ignored by external users

@Library('xmos_jenkins_shared_library@v0.45.0') _

getApproval()
pipeline {
  agent none

  parameters {
    string(
      name: 'TOOLS_VERSION',
      defaultValue: '15.3.1',
      description: 'The XTC tools version'
    )
    string(
      name: 'XMOSDOC_VERSION',
      defaultValue: 'v8.0.1',
      description: 'The xmosdoc version'
    )
    string(
      name: 'TOOLS_VX4_VERSION',
      defaultValue: '-j --repo arch_vx_slipgate -b master -a XTC 112',
      description: 'The XTC Slipgate tools version'
    )
    string(
      name: 'INFR_APPS_VERSION',
      defaultValue: 'v3.3.0',
      description: 'The infr_apps version'
    )
    choice(
        name: 'TEST_LEVEL', choices: ['smoke', 'nightly'],
        description: 'The level of test coverage to run')
  }

  options {
    skipDefaultCheckout()
    timestamps()
    buildDiscarder(xmosDiscardBuildSettings(onlyArtifacts = false))
  }


  stages {
      stage('🏗️ Build') {
        parallel {
          stage('Build examples, docs, lib checks') {
            agent {
              label 'documentation && x86_64 && linux'
            }
            stages {
              stage('Checkout') {
                steps {

                  println "Stage running on ${env.NODE_NAME}"

                  script {
                    def (server, user, repo) = extractFromScmUrl()
                    env.REPO_NAME = repo
                  }
                  dir(REPO_NAME){
                    checkoutScmShallow()
                  }
                }
              }  // stage('Checkout')

              stage('Examples build') {
                steps {
                  dir("${REPO_NAME}/examples") {
                    xcoreBuild()
                  }
                }
              }
              stage('Repo checks') {
                steps {
                  warnError("Repo checks failed")
                  {
                    runRepoChecks("${WORKSPACE}/${REPO_NAME}")
                  }
                }
              }
              stage('Doc build') {
                steps {
                  dir(REPO_NAME) {
                    buildDocs()
                  }
                }
              }
              stage("Archive Lib") {
                steps {
                  archiveSandbox(REPO_NAME)
                }
              } //stage("Archive Lib")

            } // stages
            post {
              cleanup {
                xcoreCleanSandbox()
              }
            }
          } // stage('Build examples, docs, lib checks')
          stage('Tests build') {
            agent {
              label 'x86_64 && linux'
            }
            steps {
              script {
                def (server, user, repo) = extractFromScmUrl()
                env.REPO_NAME = repo
              }
              dir(REPO_NAME) {
                checkoutScmShallow()
                dir("tests") {
                  createVenv(reqFile: "requirements.txt")
                  withVenv {
                    xcoreBuild()
                    stash includes: '**/*.xe', name: 'test_bin', useDefaultExcludes: false
                  }
                }
              }
            } // steps
          } // stage('Tests build')
        } // parallel
    }  // stage 'Build'

    stage('Custom CMake build test') {
      agent {
        label "x86_64 && linux"
      }
      steps {
        sh "git clone git@github.com:xmos/xmos_cmake_toolchain.git --branch v1.0.0"
        dir(REPO_NAME) {
          checkoutScmShallow()
          withTools(params.TOOLS_VERSION) {
            sh "cmake -B build.xcore -DDEV_LIB_MIC_ARRAY=1 -DCMAKE_TOOLCHAIN_FILE=../xmos_cmake_toolchain/xs3a.cmake"
            sh "cd build.xcore && make all -j 16"
          }
        }
      }
      post {
        cleanup {
          xcoreCleanSandbox()
        }
      }
    } // stage('Custom CMake build')
    
    stage('Tests') {
      parallel {
        stage('XS3 Tests') {
          agent {label 'xcore.ai'}
          stages {
            stage("Checkout and Build") {
              steps {
                dir(REPO_NAME) {
                  checkoutScmShallow()
                  println "Stage running on ${env.NODE_NAME}"
                  dir("tests") {
                    createVenv(reqFile: "requirements.txt")
                    unstash "test_bin"
                  }
                }
              }
            } // stage("Checkout and Build")
            stage('Run tests') {
              steps {
                dir("${REPO_NAME}/tests") {
                  withTools(params.TOOLS_VERSION) {
                    withVenv {

                      // This ensures a project for XS2 can be built and runs OK
                      sh "xsim test_xs2_benign/bin/xs2.xe"

                      // Run this first to ensure the XTAG is up and running for subsequent tests
                      timeout(time: 2, unit: 'MINUTES') {
                        sh "xrun --xscope --id 0 unit/bin/tests-unit.xe"
                      }

                      // note no xdist for HW tests as only 1 hw instance
                      // Each test has it's own conftest.py so we need to run these seprarately
                      dir("signal/pdmrx_isr") {
                          runPytest('-v --numprocesses=1')
                      }
                      dir("signal/shutdown") {
                          runPytest('-v --numprocesses=1')
                      }
                      dir("signal/BasicMicArray") {
                          script {
                            if(params.TEST_LEVEL == 'smoke')
                            {
                              echo "Running tests with fixed seed 12345"
                              sh "pytest -v --junitxml=pytest_basic_mic.xml --seed 12345 --level ${params.TEST_LEVEL} "
                            }
                            else
                            {
                              echo "Running tests with random seed"
                              sh "pytest -v --junitxml=pytest_basic_mic.xml --level ${params.TEST_LEVEL} "
                            }
                          }
                      }
                      dir("signal/TwoStageDecimator") {
                          runPytest('-v --numprocesses=1')
                      }
                      dir("signal/FilterDesign") {
                          runPytest('-v')
                      }
                      dir("signal/profile") {
                          sh "pytest -v"
                      }
                    }
                  }
                  archiveArtifacts artifacts: "**/*.pkl", allowEmptyArchive: true
                }
              }
            } // stage('Run tests')
          } // stages
          post {
            cleanup {xcoreCleanSandbox()}
          } // post
        } // XS3 Tests

        stage('VX4 Tests') {
          agent {label "vx4"}
          stages {
            stage("Checkout and Build") {
              steps {
              dir(REPO_NAME){
                checkoutScmShallow()
                dir("tests/unit") {
                  xcoreBuild(buildTool: "xmake", toolsVersion: params.TOOLS_VX4_VERSION)
                }
                dir ("tests/signal/BasicMicArray") {
                  createVenv(reqFile: "requirements.txt")
                  withVenv {
                    xcoreBuild(buildTool: "xmake", toolsVersion: params.TOOLS_VX4_VERSION)
                  }
                }
              }}
            } // stage("Checkout and Build")
            stage('Run tests') {
              steps {
              dir(REPO_NAME){    
              dir("tests/unit") {
                withTools(params.TOOLS_VX4_VERSION) {sh "xrun --xscope bin/tests-unit.xe"}
              }}}} // stage('Run tests')
          } // stages
          post {
            cleanup {xcoreCleanSandbox()}
          } //post
        } // VX4 Tests
      
      } // parallel
    } // stage('Tests')

    stage('🚀 Release') {
      when {
        expression { triggerRelease.isReleasable() }
      }
      steps {
        triggerRelease()
      }
    } // Release stage
  } // stages
} // pipeline
