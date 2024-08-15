package rpc

import (
	"io"
	"os"

	boshlog "github.com/cloudfoundry/bosh-utils/logger"

	"github.com/cloudfoundry/bosh-cpi-go/apiv1"
)

type Factory struct {
	logger boshlog.Logger
}

func NewFactory(logger boshlog.Logger) Factory {
	return Factory{logger}
}

func (f Factory) NewCLI(cpiFactory apiv1.CPIFactory) CLI {
	return f.NewCLIWithInOut(os.Stdin, os.Stdout, cpiFactory)
}

func (f Factory) NewCLIWithInOut(in io.Reader, out io.Writer, cpiFactory apiv1.CPIFactory) CLI {
	actionFactory := apiv1.NewActionFactory(cpiFactory)
	caller := NewJSONCaller()
	disp := NewJSONDispatcher(actionFactory, caller, f.logger)
	return NewCLI(in, out, disp, f.logger)
}
