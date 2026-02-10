// This file relates to internal XMOS infrastructure and should be ignored by external users

@Library('xmos_jenkins_shared_library@develop') _

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
      name: 'TOOLS_VX4_VERSION',
      defaultValue: '-j --repo arch_vx_slipgate -b master -a XTC 108',
      description: 'The XTC Slipgate tools version'
    )
    string(
      name: 'XMOSDOC_VERSION',
      defaultValue: 'v8.0.1',
      description: 'The xmosdoc version')

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

    stage('Test XS3') {
      parallel {
        stage('XCommon build ') {
          agent {
            label "x86_64 && linux"
          }
          steps {
            println "Stage running on ${env.NODE_NAME}"
            dir(REPO_NAME){
              checkoutScmShallow()
              dir("tests") {
                withTools(params.TOOLS_VERSION) {
                  sh 'cmake -B build -G "Unix Makefiles"'
                  // Note no -C build so builds the xcommon Makefile
                  sh "xmake all -j 16"
                }
                archiveArtifacts artifacts: "**/*.xe", allowEmptyArchive: true
              }
            }
          }
          post {
            cleanup {
              xcoreCleanSandbox()
            }
          } //post
        } // stage('XCommon build')
        stage('Custom CMake build') {
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
        stage('HW tests') {
          agent {
            label 'xcore.ai'
          }
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
                      // Use xtagctl to reset the relevent adapters first, if attached, to be safe.
                      // sh "xtagctl reset_all XVF3800_INT XVF3600_USB"

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
            cleanup {
              xcoreCleanSandbox()
            }
          }
        } // stage('HW tests')
      } // parallel
    } // stage('Test')
    
    stage('Test VX4') {
      dir("${REPO_NAME}/tests/unit") {
        xcoreBuild(buildTool: "xmake", toolsVersion: params.TOOLS_SLIPGATE_VERSION)
        sh "xsim bin/tests-unit.xe"
      }
      post {
        cleanup {
          xcoreCleanSandbox()
        }
      }
    }

    stage('🚀 Release') {
      when {
        expression { triggerRelease.isReleasable() }
      }
      steps {
        triggerRelease()
      }
    }
  } // stages
} // pipeline
