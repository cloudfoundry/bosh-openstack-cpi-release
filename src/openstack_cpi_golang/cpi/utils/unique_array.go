package utils

func UniqueArray(input []string) []string {
	uniqueMap := make(map[string]bool)

	uniqueSlice := make([]string, 0)
	for _, entry := range input {
		if _, value := uniqueMap[entry]; !value {
			uniqueMap[entry] = true
			uniqueSlice = append(uniqueSlice, entry)
		}
	}
	return uniqueSlice
}
