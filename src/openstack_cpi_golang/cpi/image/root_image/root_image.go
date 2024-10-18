package root_image

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

//counterfeiter:generate . RootImage
type RootImage interface {
	Get(stemcellImagePath string, targetDirPath string) (string, error)
}

type rootImage struct {
}

func NewRootImage() rootImage {
	return rootImage{}
}

func (h rootImage) Get(stemcellImagePath string, targetDirPath string) (string, error) {
	cmd := exec.Command("tar", "-C", targetDirPath, "-xzf", stemcellImagePath)
	out, err := cmd.CombinedOutput()
	if err != nil {
		return "", fmt.Errorf("failed to extract stemcell root image to %s, tar returned %s, error: %s", targetDirPath, out, err)
	}

	rootImagePath := filepath.Join(targetDirPath, "root.img")
	if _, err := os.Stat(rootImagePath); os.IsNotExist(err) {
		return "", fmt.Errorf("root image is missing from stemcell archive")
	}

	return rootImagePath, nil
}
