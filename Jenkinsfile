@Library('xmos_jenkins_shared_library@v0.34.0') _
getApproval()
pipeline {
    agent none

    environment {
        REPO = 'lib_mic_array'
        PIP_VERSION = "24.0"
        PYTHON_VERSION = "3.11"
        XMOSDOC_VERSION = "v6.0.0"          
    }
    options {
        skipDefaultCheckout()
        timestamps()
        // on develop discard builds after a certain number else keep forever
        buildDiscarder(logRotator(
            numToKeepStr:         env.BRANCH_NAME ==~ /develop/ ? '25' : '',
            artifactNumToKeepStr: env.BRANCH_NAME ==~ /develop/ ? '25' : ''
        ))
    }
    parameters {
        string(
            name: 'TOOLS_VERSION',
            defaultValue: '15.3.0',
            description: 'The XTC tools version'
        )
    }
    stages {
        stage('Build and Docs') {
            parallel {
                stage('Documentation') {
                    agent {
                        label "docker"
                    }
                    steps {
                        dir("${REPO}") {
                            warnError("Docs") {
                                checkout scm
                                sh "docker pull ghcr.io/xmos/xmosdoc:$XMOSDOC_VERSION"
                                sh """docker run -u "\$(id -u):\$(id -g)" \
                                      --rm \
                                      -v \$(pwd):/build \
                                      ghcr.io/xmos/xmosdoc:$XMOSDOC_VERSION -v html latex"""

                                // Zip and archive doc files
                                zip dir: "doc/_build/html", zipFile: "${REPO}_docs_html.zip"
                                archiveArtifacts artifacts: "${REPO}_docs_html.zip"
                                archiveArtifacts artifacts: "doc/_build/pdf/${REPO}*.pdf"
                            }
                        }
                    }
                    post {
                        cleanup {
                            xcoreCleanSandbox()
                        }
                    }
                }
                stage('XCommon build') {
                    agent {
                        label "x86_64 && linux"
                    }
                    steps {
                        dir("${REPO}") {
                            checkout scm
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
                    }
                }
                stage('Custom CMake build') {
                    agent {
                        label "x86_64 && linux" 
                    }
                    steps {
                        sh "git clone git@github.com:xmos/xmos_cmake_toolchain.git --branch v1.0.0"
                        dir("${REPO}") {
                            checkout scm
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
                }
                stage('XCCM build and basic tests') {
                    agent {
                        label 'x86_64 && linux'
                    }
                    stages {
                        stage("XCCM Build") {
                            // Clone and install build dependencies
                            steps {
                                // Clone infrastructure repos
                                sh "git clone --branch v1.6.0 git@github.com:xmos/infr_apps"
                                sh "git clone --branch v1.3.0 git@github.com:xmos/infr_scripts_py"
                                // clone
                                dir("${REPO}") {
                                    checkout scm
                                    createVenv(reqFile: "requirements.txt")
                                    withVenv {
                                        withTools(params.TOOLS_VERSION) {
                                            dir("examples") {
                                                sh 'cmake -B build -G "Unix Makefiles"'
                                                sh 'xmake -j 16 -C build'
                                            }
                                        }
                                    }
                                    archiveArtifacts artifacts: "**/*.xe", allowEmptyArchive: true
                                }
                            }
                        }
                        stage("Lib checks") {
                            steps {
                                warnError("lib checks") {
                                    runLibraryChecks("${WORKSPACE}/${REPO}", "v2.0.1")
                                }
                            }
                        }
                    }
                    post {
                        cleanup {
                            xcoreCleanSandbox()
                        }
                    }
                }
                stage('HW tests') {
                    agent {
                        label 'xcore.ai' // Did include xvf3800 but XTAG speed meant occasional test fail
                    }
                    stages {
                        stage("Checkout and Build") {
                            steps {
                                dir("${REPO}") {
                                    println "RUNNING ON"
                                    println env.NODE_NAME
                                    checkout scm
                                    createVenv(reqFile: "requirements.txt")
                                    withVenv {
                                        withTools(params.TOOLS_VERSION) {
                                            dir("tests") {
                                                sh 'cmake -B build -G "Unix Makefiles"'
                                                sh 'xmake -j 8 -C build'
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        stage('Run tests') {
                            steps {
                                dir("${REPO}/tests") {
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
                                            dir("signal/BasicMicArray") {
                                                runPytest('-vv --numprocesses=1')
                                            }
                                            dir("signal/TwoStageDecimator") {
                                                runPytest('-vv --numprocesses=1')
                                            }
                                            dir("signal/FilterDesign") {
                                                runPytest('-vv')
                                            }
                                        }
                                    }
                                    archiveArtifacts artifacts: "**/*.pkl", allowEmptyArchive: true
                                }
                            }
                        }
                    }
                    post {
                        cleanup {
                            xcoreCleanSandbox()
                        }
                    }
                }
            }
        }
    }
}
