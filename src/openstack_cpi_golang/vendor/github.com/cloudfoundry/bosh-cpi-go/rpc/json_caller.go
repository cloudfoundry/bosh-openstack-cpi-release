package rpc

import (
	"encoding/json"
	"reflect"

	bosherr "github.com/cloudfoundry/bosh-utils/errors"
)

// JSONCaller unmarshals call arguments with json package and calls action.Run
type JSONCaller struct{}

func NewJSONCaller() JSONCaller {
	return JSONCaller{}
}

func (r JSONCaller) Call(action interface{}, args []interface{}) (value interface{}, err error) {
	actionValue := reflect.ValueOf(action)

	var runMethodValue reflect.Value

	if actionValue.Kind() == reflect.Func {
		runMethodValue = actionValue
	} else {
		runMethodValue = actionValue.MethodByName("Run")
		if runMethodValue.Kind() != reflect.Func {
			err = bosherr.Error("Run method not found")
			return
		}
	}

	runMethodType := runMethodValue.Type()
	if r.invalidReturnTypes(runMethodType) {
		err = bosherr.Error("Run method should return a value and an error")
		return
	}

	methodArgs, err := r.extractMethodArgs(runMethodType, args)
	if err != nil {
		err = bosherr.WrapError(err, "Extracting method arguments from payload")
		return
	}

	values := runMethodValue.Call(methodArgs)
	return r.extractReturns(runMethodType, values)
}

func (r JSONCaller) invalidReturnTypes(methodType reflect.Type) (valid bool) {
	if methodType.NumOut() == 0 {
		return true
	}

	lastReturnType := methodType.Out(methodType.NumOut() - 1)
	if lastReturnType.Kind() != reflect.Interface {
		return true
	}

	errorType := reflect.TypeOf(bosherr.Error(""))
	secondReturnIsError := errorType.Implements(lastReturnType)
	if !secondReturnIsError {
		return true
	}

	return false
}

func (r JSONCaller) extractMethodArgs(runMethodType reflect.Type, args []interface{}) (methodArgs []reflect.Value, err error) {
	numberOfArgs := runMethodType.NumIn()
	numberOfReqArgs := numberOfArgs

	if runMethodType.IsVariadic() {
		numberOfReqArgs--
	}

	if len(args) < numberOfReqArgs {
		err = bosherr.Errorf("Not enough arguments, expected %d, got %d", numberOfReqArgs, len(args))
		return
	}

	for i, argFromPayload := range args {
		var rawArgBytes []byte
		rawArgBytes, err = json.Marshal(argFromPayload)
		if err != nil {
			err = bosherr.WrapError(err, "Marshalling action argument")
			return
		}

		argType, typeFound := r.getMethodArgType(runMethodType, i)
		if !typeFound {
			continue
		}

		argValuePtr := reflect.New(argType)

		err = json.Unmarshal(rawArgBytes, argValuePtr.Interface())
		if err != nil {
			err = bosherr.WrapError(err, "Unmarshalling action argument")
			return
		}

		methodArgs = append(methodArgs, reflect.Indirect(argValuePtr))
	}

	return
}

func (r JSONCaller) getMethodArgType(methodType reflect.Type, index int) (argType reflect.Type, found bool) {
	numberOfArgs := methodType.NumIn()

	switch {
	case !methodType.IsVariadic() && index >= numberOfArgs:
		return nil, false

	case methodType.IsVariadic() && index >= numberOfArgs-1:
		sliceType := methodType.In(numberOfArgs - 1)
		return sliceType.Elem(), true

	default:
		return methodType.In(index), true
	}
}

func (r JSONCaller) extractReturns(methodType reflect.Type, values []reflect.Value) (interface{}, error) {
	var err error

	errValue := values[methodType.NumOut()-1]
	if !errValue.IsNil() {
		err = errValue.Interface().(error)
	}

	switch {
	case methodType.NumOut() == 1:
		return nil, err
	case methodType.NumOut() == 2:
		return values[0].Interface(), err
	default:
		returnValues := []interface{}{}
		for i := 0; i < methodType.NumOut()-1; i++ {
			returnValues = append(returnValues, values[i].Interface())
		}
		return returnValues, err
	}
}
