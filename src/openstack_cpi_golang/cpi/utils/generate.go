package utils

//go:generate go run github.com/maxbrunsfeld/counterfeiter/v6 -generate

//counterfeiter:generate -o utilsfakes/fake_logger.go github.com/cloudfoundry/bosh-utils/logger.Logger
