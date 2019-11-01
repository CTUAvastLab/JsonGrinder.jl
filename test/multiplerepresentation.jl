using JsonGrinder, JSON, Test

ex = MultipleRepresentation((ExtractCategorical(["Olda", "Tonda", "Milda"]),
	JsonGrinder.ExtractString(String)))

ex("Olda")