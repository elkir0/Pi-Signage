package main

import (
	"os"
	"path/filepath"
)

// writeFile0600 writes data atomically with mode 0600 (owner-only). Every file
// the agent persists (private key, wg.json data file, enrollment.json) is
// pi-owned and owner-only; the agent never writes a privileged/root-owned path.
func writeFile0600(path string, data []byte) error {
	return atomicWrite(path, data, 0600)
}

func atomicWrite(path string, data []byte, mode os.FileMode) error {
	dir := filepath.Dir(path)
	if err := os.MkdirAll(dir, 0700); err != nil {
		return err
	}
	tmp, err := os.CreateTemp(dir, ".zf-*.tmp")
	if err != nil {
		return err
	}
	tmpName := tmp.Name()
	defer os.Remove(tmpName) // no-op if rename succeeded
	if _, err := tmp.Write(data); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Chmod(mode); err != nil {
		tmp.Close()
		return err
	}
	if err := tmp.Close(); err != nil {
		return err
	}
	return os.Rename(tmpName, path)
}
