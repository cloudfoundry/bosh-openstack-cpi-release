package rpc

import (
	"io"
	"io/ioutil"

	bosherr "github.com/cloudfoundry/bosh-utils/errors"
	boshlog "github.com/cloudfoundry/bosh-utils/logger"
)

type CLI struct {
	in         io.Reader
	out        io.Writer
	dispatcher Dispatcher

	logTag string
	logger boshlog.Logger
}

func NewCLI(in io.Reader, out io.Writer, dispatcher Dispatcher, logger boshlog.Logger) CLI {
	return CLI{
		in:         in,
		out:        out,
		dispatcher: dispatcher,

		logTag: "CLI",
		logger: logger,
	}
}

func (t CLI) ServeOnce() error {
	reqBytes, err := ioutil.ReadAll(t.in)
	if err != nil {
		t.logger.Error(t.logTag, "Failed reading from IN: %s", err)
		return bosherr.WrapError(err, "Reading from IN")
	}

	respBytes := t.dispatcher.Dispatch(reqBytes)

	_, err = t.out.Write(respBytes)
	if err != nil {
		t.logger.Error(t.logTag, "Failed writing to OUT: %s", err)
		return bosherr.WrapError(err, "Writing to OUT")
	}

	return nil
}
