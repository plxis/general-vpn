import groovy.json.JsonSlurper
import groovy.json.JsonBuilder
import util.AttemptsExhaustedException
import util.DateTime
import util.Wait
import util.TimeoutException
import toxic.VariableReplacer


memory.resetShipyardEnvironment = { file=null ->
  if (!file) file = memory.environmentFile

  def contents = new File(file).text
  
  def varRep = new VariableReplacer()
  varRep.init(memory)

  memory.environment = new JsonSlurper().parseText(varRep.replace(contents))
}

memory.shipyard = { action, environment=[:]->
  def envFile = new File(memory.environmentFile)

  if (environment) {
    envFile = new File("${memory.tmpDir}/shipyard-env-${System.currentTimeMillis()}.json")
    envFile.text = new JsonBuilder(memory.environment).toString()
  }

  def cmds = []
  cmds << "docker"
  cmds << "run"
  cmds << "--rm"
  cmds << "--cap-add"
  cmds << "IPC_LOCK"
  cmds << "-e"
  cmds << "AWS_DEFAULT_PROFILE=${memory.awsProfile}"
  cmds << "-v"
  cmds << "${System.getenv('HOME')}/.aws:/home/shipyard/.aws:ro"
  cmds << "-v"
  cmds << "${envFile.absolutePath}:/environment.json"
  cmds << "-v"
  cmds << "${memory.tmpDir}:/tmp:rw"
  cmds << "-v"
  cmds << "${new File(memory.tfWorkDir).absolutePath}:/tf-work"
  if (memory.localProjectDir) {
    cmds << "-v"
    cmds << "${memory.localProjectDir}/terraform:/opt/general-vpn-provisioning/current/terraform:ro"
  }
  cmds << memory.shipyardImage
  cmds << action

  int result = 1

  try {
    result = execWithEnv(cmds, [:], 1800)
  }
  finally {
    if (environment) envFile.delete()
  }

  memory.lastResponse = out.toString().trim()
  memory.lastError = err.toString().trim()

  return result
}

memory.awsCmd = { cmdLine ->
  def cmds = []
  cmds << "docker"
  cmds << "run"
  cmds << "--rm"
  cmds << "-e"
  cmds << "AWS_DEFAULT_PROFILE=${memory.awsProfile}"
  cmds << "-v"
  cmds << "${System.getenv('HOME')}/.aws:/root/.aws:ro"
  cmds << "-t"
  cmds << "--entrypoint"
  cmds << "/bin/bash"
  cmds << memory.shipyardImage
  cmds << "-c"
  cmds << cmdLine.toString()

  int result = execWithEnv(cmds, [:], 900)

  memory.lastResponse = out.toString().trim()
  memory.lastError = err.toString().trim()

  return result
}

memory.getValue = { src, key, terminator = '\n', includeTerminator=false ->
  def startIdx = src.indexOf(key) + key.size()
  def endIdx = src.indexOf(terminator, startIdx)
  if (includeTerminator) endIdx += terminator.size()
  endIdx = endIdx > 0 ? endIdx - 1 : -1
  return src[startIdx..endIdx]?.trim()
}



// Default logic for determining if a closure was successful. Assumes that the closure
// returns an error code value (int), with 0 indicating success
def defaultSuccessCheck = { result ->
  //log.info("Checking success for result value ${result}")
  result != null && result == 0
}

def defaultBeforeRetry = { attemptNum ->
  log.info("Retrying because attempt ${attemptNum} did not pass the success check")
}
memory.defaultBeforeRetry = defaultBeforeRetry

// Executes a closure, repeating it up to maxAttempts times or timeoutSecs seconds (whichever comes first).
// Waits delaySec seconds between retries, optionally executing beforeRetry closure before retrying
// It as assumed that the closure returns an error code value, with 0 indicating success and anything else
// (including throwing an exception) indicating failure. The determination of success can be overriden
// using the successCheck parameter (a closure)
memory.runWithRetry = { maxAttempts, totalTimeoutSecs, closure, delaySecs=0, beforeRetry=defaultBeforeRetry, successCheck = defaultSuccessCheck ->

  Wait waiter = Wait.on(closure).every(delaySecs * 1000).beforeRetry(beforeRetry).forCondition(successCheck)
  if(maxAttempts != null && maxAttempts > 0) {
    waiter = waiter.atMostAttempts(maxAttempts)
  }
  if(totalTimeoutSecs != null && totalTimeoutSecs > 0) {
    waiter = waiter.atMostMs(totalTimeoutSecs * 1000)
  }
  if(!(waiter.maxAttempts || waiter.timeout )) {
    throw new IllegalArgumentException("Must specify either max attempts or max retries")
  }

  def handleWaitEx = { ex ->
    def execTime = String.format("%.3f", (DateTime.now().getTime() - waiter.start.getTime())/1000.0)
    log.warn("Failed after ${waiter.attemptCount} attempts over ${execTime} seconds")
    throw ex
  }

  // Execute
  try {
    waiter.start()
  } catch(TimeoutException ex) { handleWaitEx(ex) }
  catch(AttemptsExhaustedException ex) { handleWaitEx(ex) }
  return waiter.lastResult
}
