@Library('xmos_jenkins_shared_library@v0.33.0') _
getApproval()
pipeline {
    agent none
    options {
        disableConcurrentBuilds()
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
    environment {
        REPO = 'lib_mic_array'
    }
    stages {
        stage('Build and Docs') {
            parallel {
                stage('Build Docs') {
                    agent { label "docker" }
                    environment { XMOSDOC_VERSION = "v4.0" }
                    steps {
                        checkout scm
                        sh 'git submodule update --init --recursive --depth 1'
                        sh "docker pull ghcr.io/xmos/xmosdoc:$XMOSDOC_VERSION"
                        sh """docker run -u "\$(id -u):\$(id -g)" \
                            --rm \
                            -v ${WORKSPACE}:/build \
                            ghcr.io/xmos/xmosdoc:$XMOSDOC_VERSION -v"""
                        archiveArtifacts artifacts: "doc/_build/**", allowEmptyArchive: true
                    }
                    post {
                        cleanup {
                            xcoreCleanSandbox()
                        }
                    }
                }
                stage('Basic tests') {
                    when {
                        expression { !env.GH_LABEL_DOC_ONLY.toBoolean() }
                    }
                    agent {
                        label 'x86_64 && linux'
                    }
                    stages {
                        stage("Setup") {
                            // Clone and install build dependencies
                            steps {
                                // Print the build agent name
                                println "RUNNING ON"
                                println env.NODE_NAME
                                // Clone infrastructure repos
                                sh "git clone --branch v1.6.0 git@github.com:xmos/infr_apps"
                                sh "git clone --branch v1.3.0 git@github.com:xmos/infr_scripts_py"
                                // clone
                                dir("$REPO") {
                                    checkout scm
                                    sh "git submodule update --init --recursive"
                                    withTools(params.TOOLS_VERSION) {
                                        installDependencies()
                                    }
                                }
                            }
                        }
                        stage("Lib checks") {
                            steps {
                                println "Unlikely these will pass.."
                                // warnError("Source Check"){ sourceCheck("${REPO}") }
                                // warnError("Changelog Check"){ xcoreChangelogCheck("${REPO}") }
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
        stage('HW tests') {
            when {
                expression { !env.GH_LABEL_DOC_ONLY.toBoolean() }
            }
            agent {
                label 'xvf3800' // We have plenty of these (6) and they have a single XTAG connected
            }
            stages {
                stage("Setup") {
                    // Clone and install build dependencies
                    steps {
                        // clone
                        dir("$REPO") {
                            println "RUNNING ON"
                            println env.NODE_NAME
                            checkout scm
                            sh "git submodule update --init --recursive"
                            withTools(params.TOOLS_VERSION) {
                                installDependencies()
                            }
                        }
                    }
                }
                stage("Build firmware") {
                    steps {
                        withTools(params.TOOLS_VERSION) {
                            dir("$REPO"){
                                sh ". .github/scripts/build_test_apps.sh"
                            }
                        }
                    }
                }
                stage('Run tests') {
                    steps {
                        dir("${REPO}") {
                            withTools(params.TOOLS_VERSION) {
                                withVenv {
                                    // Use xtagctl to reset the relevent adapters first, if attached, to be safe.
                                    // sh "xtagctl reset_all XVF3800_INT XVF3600_USB"
                                    sh ". .github/scripts/run_test_apps.sh"
                                }
                            }
                        }
                        dir("${REPO}/..") {
                            // archiveArtifacts artifacts: "src/BeClearMemory.S", fingerprint: true
                        }
                    }
                }
            }
            post {
                cleanup {
                    xcoreCleanSandbox()
                    cleanWs()
                }
            }
        }
    }
}
