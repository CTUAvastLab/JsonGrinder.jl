# universal extractor for extractors accomanying trained models
struct AuxiliaryExtractor <: AbstractExtractor
	extractor::AbstractExtractor
	extract_fun::Function
end

(e::AuxiliaryExtractor)(x) = e.extract_fun(e.extractor, x)
