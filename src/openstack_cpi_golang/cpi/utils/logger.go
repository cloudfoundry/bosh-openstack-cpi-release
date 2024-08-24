package utils

import boshlog "github.com/cloudfoundry/bosh-utils/logger"

//counterfeiter:generate . Logger
type Logger interface {
	Info(tag, msg string, args ...interface{})

	Warn(tag, msg string, args ...interface{})

	Error(tag, msg string, args ...interface{})

	Debug(tag, msg string, args ...interface{})

	HandlePanic(tag string)

	TargetLogger() boshlog.Logger
}

type logger struct {
	logger boshlog.Logger
}

func NewLogger(log boshlog.Logger) logger {
	return logger{
		logger: log,
	}
}

func (l logger) Info(tag, msg string, args ...interface{}) {
	l.logger.Info(tag, msg, args)
}

func (l logger) Warn(tag, msg string, args ...interface{}) {
	l.logger.Warn(tag, msg, args)
}

func (l logger) Error(tag, msg string, args ...interface{}) {
	l.logger.Error(tag, msg, args)
}

func (l logger) Debug(tag, msg string, args ...interface{}) {
	l.logger.Debug(tag, msg, args)
}

func (l logger) HandlePanic(tag string) {
	l.logger.HandlePanic(tag)
}

func (l logger) TargetLogger() boshlog.Logger {
	return l.logger
}
