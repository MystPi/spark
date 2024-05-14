import * as $gleam from './gleam.mjs';
import * as $error from './spark/error.mjs';

export function downloadTar(url, outputDir) {
  const wget_command = Bun.spawnSync(['wget', '-q', '-O', '-', url]);

  if (!wget_command.success)
    return new $gleam.Error(
      $error.simple_error('Failed to download tarball from ' + url)
    );

  const tar_command = Bun.spawnSync(
    ['tar', 'xzC', outputDir, '--strip-components=1'],
    {
      stdin: wget_command.stdout,
    }
  );

  if (!tar_command.success)
    return new $gleam.Error(
      $error.simple_error('Failed to extract tarball to ' + outputDir)
    );

  return new $gleam.Ok();
}

export function now() {
  return performance.now();
}
