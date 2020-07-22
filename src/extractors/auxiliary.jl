# universal extractor for applying any function, useful e.g. for extractors accompanying trained models
struct AuxiliaryExtractor <: AbstractExtractor
	extractor::AbstractExtractor
	extract_fun::Function
end

(e::AuxiliaryExtractor)(x) = e.extract_fun(e.extractor, x)
