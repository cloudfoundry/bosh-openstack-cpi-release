package root_image

import (
	"os"

	. "github.com/onsi/ginkgo/v2"
	. "github.com/onsi/gomega"
)

var _ = Describe("RootImage", func() {
	var targetDirPath string

	Context("Get", func() {
		BeforeEach(func() {
			targetDirPath, _ = os.MkdirTemp("/tmp", "unpacked-image-")
		})

		AfterEach(func() {
			os.RemoveAll(targetDirPath)
		})

		It("returns the root.img path", func() {
			rootImagePath, err := NewRootImage().Get("testdata/image", targetDirPath)

			Expect(err).ToNot(HaveOccurred())
			Expect(rootImagePath).To(MatchRegexp("/tmp/unpacked-image-[0-9]+/root.img"))
		})

		It("fails if the root.img cannot be found", func() {
			rootImagePath, err := NewRootImage().Get("testdata/image_without_root_img", targetDirPath)

			Expect(err.Error()).To(Equal("root image is missing from stemcell archive"))
			Expect(rootImagePath).To(Equal(""))
		})

		It("fails if the image cannot be extracted", func() {
			rootImagePath, err := NewRootImage().Get("testdata/image_that_is_no_tar", targetDirPath)

			Expect(err.Error()).To(MatchRegexp("failed to extract stemcell root image to .*"))
			Expect(rootImagePath).To(Equal(""))
		})

		It("fails if the image cannot be found", func() {
			rootImagePath, err := NewRootImage().Get("testdata/image_not_existing", targetDirPath)

			Expect(err.Error()).To(MatchRegexp("failed to extract stemcell root image to .*"))
			Expect(rootImagePath).To(Equal(""))
		})
	})
})
