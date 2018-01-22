import java.nio.file.Files
import java.nio.file.attribute.PosixFilePermission

// Prepare the temp directory we'll use for the remainder of this test
new File(memory.tmpDir).deleteDir()
new File(memory.tmpDir).mkdirs()
assert 0 == exec("chmod 777 ${memory.tmpDir}")

// Create a working dir within toxic artifacts dir
if(!memory.tfWorkDir) {
  memory.tfWorkDir = "${memory.toxicArtifactsDirectory}/tf-work"
}
def tfWorkDir = new File(memory.tfWorkDir)
if(!tfWorkDir.exists()) { tfWorkDir.mkdirs() }
assert tfWorkDir.exists()

// Open up permissions on work dir
Files.setPosixFilePermissions(tfWorkDir.toPath(), new HashSet([
        PosixFilePermission.OWNER_READ, PosixFilePermission.OWNER_WRITE, PosixFilePermission.OWNER_EXECUTE,
        PosixFilePermission.GROUP_READ, PosixFilePermission.GROUP_WRITE, PosixFilePermission.GROUP_EXECUTE,
        PosixFilePermission.OTHERS_READ, PosixFilePermission.OTHERS_WRITE, PosixFilePermission.OTHERS_EXECUTE
]))
