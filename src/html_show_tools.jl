using Mustache: @mt_str, render
using Printf: @sprintf
using HttpCommon: escapeHTML
using ThreadTools: tmap
using DataStructures: OrderedDict
using StatsBase: RealVector, fweights
import Statistics: quantile, mean

# used tableau 10 colormap
HTML_COLORS = ["#4E79A7","#F28E2C","#E15759","#76B7B2","#59A14F", "#EDC949","#AF7AA1","#FF9DA7","#9C755F","#BAB0AB"]

quantile(v::Dict{Int, Int}, p::Number) = quantile(v |> keys |> collect, v |> values |> collect |> fweights, [p])[1]
quantile(v::Dict{Int, Int}, p::RealVector) = quantile(v |> keys |> collect, v |> values |> collect |> fweights, p)
mean(v::Dict{Int, Int}) = mean(v |> keys |> collect, v |> values |> collect |> fweights)
stringify(arg::Pair; max_len=1_000) = stringify(arg.first, arg.second, max_len=max_len)
stringify(arg1::String, arg2; max_len=1_000) = isnothing(max_len) ? "$(escapeHTML(arg1)): $(arg2)" : "$(escapeHTML(first(arg1, max_len))): $(arg2)"
stringify(arg1, arg2; max_len=1_000) = "$(arg1): $(arg2)"
calc_filled_percent(e, parent_updated) = isnothing(parent_updated) ? "" : @sprintf ", filled=%.2f%%" (100 * e.updated / parent_updated)
pad_color(pad) = HTML_COLORS[((length(pad)÷2)%length(HTML_COLORS))+1]

function pair2html(i, key, val, max_len, pad)
	pair_repr = stringify(key, val, max_len=max_len)
	pad*" "^2 * "<li>$pair_repr</li>\n"
end

function schema2html(e::Entry; pad = "", max_vals=100, max_len=1_000, parent_updated=nothing, parent_key="")
	c = pad_color(pad)
	filled_percent = calc_filled_percent(e, parent_updated)
	sorted_counts = sort(collect(e.counts), by=x->x[2], rev=true)
	min_repr = stringify(sorted_counts[end], max_len=max_len)
	max_repr = stringify(sorted_counts[1], max_len=max_len)
	ret_str = """
$pad<ul class="nested" style="color: $c">$pad[Scalar - $(join(types(e)))], $(length(keys(e.counts))) unique values,
(updated=$(e.updated)$filled_percent, min=$min_repr, max=$max_repr)
"""

	counts2process = if isnothing(max_vals)
		enumerate(sorted_counts)
	else
		Iterators.take(enumerate(sorted_counts), max_vals)
	end
	li_part = join(tmap(i->pair2html(i[1], i[2].first, i[2].second, max_len, pad), Threads.nthreads(), counts2process))
	ret_str *= li_part
	if !isnothing(max_vals) && length(sorted_counts) > max_vals
		ret_str *= pad*" "^2 * "<li>and other $(length(e.counts) - max_vals) values</li>\n"
	end
	ret_str * "$pad </ul>\n"
end

# because sometimes there is empty list in all jsons, this helps to determine the pruning of such element
function schema2html(e::Nothing; pad = "", max_vals=100, max_len=1_000, parent_updated=nothing, parent_key="")
	c = HTML_COLORS[((length(pad)÷2)%length(HTML_COLORS))+1]
	ret_str = """
$pad[Empty list element], this list is empty in all JSONs, can not infer schema, suggesting to delete key $parent_key
"""
	ret_str
end

function schema2html(e::ArrayEntry; pad = "", max_vals=100, max_len=1_000, parent_updated=nothing, parent_key="")
 	c = pad_color(pad)
	# todo: fix it all so it is different method for array of entries and the rest so only nested things are truly nested
	filled_percent = calc_filled_percent(e, parent_updated)
	quantiles = quantile(e.l, [0.1, 0.5, 0.9])
	min_val = minimum(keys(e.l))
	max_val = maximum(keys(e.l))
	mean_val = round(mean(e.l), digits=2)
	q10_val = round(quantiles[1], digits=2)
	median_val = round(quantiles[2], digits=2)
	q90_val = round(quantiles[3], digits=2)
	ret_str = """
$pad<ul class="nested" style="color: $c">[List] (updated=$(e.updated)$filled_percent, mean=$mean_val,
min=$min_val, max=$max_val, 10th percentile=$q10_val, median=$median_val, 90th percentile=$q90_val)
$pad<li><span class="caret">with following frequencies</span>
$pad<ul class="nested">
"""
 	i = 0
	sorted_el = sort(collect(e.l))
 	for (key, val) in sorted_el
		ret_str *= pad*" "^2 * "<li>$key: $val</li>\n"
		i += 1
		if !isnothing(max_vals) && i == max_vals && length(sorted_el) > max_vals
			ret_str *= pad*" "^2 * "<li>and other $(length(e.l) - i) values</li>\n"
			break
		end
 	end
	ret_str *= """
$pad</ul>
$pad</li>
$pad<li><span class="caret">and data</span>
"""
	ret_str *= schema2html(e.items, pad=pad*" "^2, max_vals=max_vals, max_len=max_len, parent_key="$parent_key.items")
	ret_str * """
$pad</li>
$pad</ul>
"""
end

function schema2html(e::DictEntry; pad = "", max_vals=100, max_len=1_000, parent_updated=nothing, parent_key="")
	c = pad_color(pad)
    if isempty(e.childs)
    	return pad * """<ul style="color: $c">Empty Dict</ul>\n"""
    end
	class = isempty(pad) ? "top_dict" : "nested"
	filled_percent = calc_filled_percent(e, parent_updated)
	ret_str = pad * """<ul class="$class" style="color: $c">[Dict] (updated=$(e.updated)$filled_percent)\n"""
	i = 0
	ordered_childs = OrderedDict(e.childs)
    for (key, val) in sort!(ordered_childs)
		child_key = """$parent_key[$(repr(Symbol(key)))]"""
		ret_str *= pad*" "^2 * """<li><span class="caret">$key</span> - <label>$child_key<input type="checkbox" name="$(escapeHTML(child_key))" value="$(escapeHTML(child_key))"></label>\n"""
		ret_str *= schema2html(val, pad=pad*" "^4, max_vals=max_vals, max_len=max_len, parent_updated=e.updated, parent_key=child_key)
		ret_str *= pad*" "^2 * "</li>\n"
		i += 1
		if !isnothing(max_vals) && i == max_vals && length(ordered_childs) > max_vals
			ret_str *= pad*" "^2 * "<li>and other $(length(e.childs) - i) values</li>\n"
			break
		end
    end
	ret_str * pad * "</ul>\n"
end

function schema2html(e::MultiEntry; pad = "", max_vals=100, max_len=1_000, parent_updated=nothing, parent_key="")
	c = pad_color(pad)
	filled_percent = calc_filled_percent(e, parent_updated)
	ret_str = pad * """<ul class="nested" style="color: $c">[MultiEntry] (updated=$(e.updated)$filled_percent)\n"""
	i = 0
    for (key, val) in enumerate(e.childs)
		child_key = """$parent_key["$key"]"""
		ret_str *= pad*" "^2 * """<li><span class="caret">$key</span> - <label>$child_key<input type="checkbox" name="$(escapeHTML(child_key))" value="$(escapeHTML(child_key))"></label>\n"""
		ret_str *= schema2html(val, pad=pad*" "^4, max_vals=max_vals, max_len=max_len, parent_updated=e.updated, parent_key=child_key)
		ret_str *= pad*" "^2 * "</li>\n"
		i += 1
		if !isnothing(max_vals) && i == max_vals && length(e.childs) > max_vals
			ret_str *= pad*" "^2 * "<li>and other $(length(e.childs) - i) values</li>\n"
			break
		end
    end
	ret_str * pad * "</ul>\n"
end
# queryselectorall v js místo getelementsbyclassname
# a zkusit minifikovat to html-vyházet odsazení, a kouknout na rozdíl velikostí

"""
	generate_html(sch::DictEntry; max_vals=100, max_len=1_000)
	generate_html(file_name, sch::DictEntry; max_vals=100, max_len=1_000)

exports schema to HTML including CSS style and JS allowing to expand / hide
sub-parts of schema, countmaps, and lengthmaps.

# Arguments
- `max_vals` controls maximum number of exported values in countmap
- `max_len` controls maximum number of exported lengts of arrays
- `file_name` a name of file to save HTML with schema

# Return
If provided filename, it does not return anything.
If not, it returns the generated HTML+CSS+JS as a String.

# Example
You can either open the html file in any browser, or open it directly using ElectronDisplay

```julia
using ElectronDisplay
using ElectronDisplay: newdisplay
generated_html = generate_html(sch, max_vals = 100)
display(newdisplay(), MIME{Symbol("text/html")}(), generated_html)
```
"""
function generate_html(sch::DictEntry; max_vals=100, max_len=1_000)
	tpl = mt"""
	<!DOCTYPE html>
	<html lang="en">
	<head>
    	<meta charset="UTF-8">
    	<title>Json schema dump</title>
    	<style>
        	ul, .top_dict {/* Remove default bullets */
            	list-style-type: none;
        	}
        	.top_dict {/* Remove margins and padding from the parent ul */
            	margin: 0;
            	padding: 0;
        	}
        	.caret {/* Style the caret/arrow */
            	cursor: pointer;
            	user-select: none; /* Prevent text selection */
        	}
        	.caret::before {/* Create the caret/arrow with a unicode, and style it */
            	content: "\25B6";
            	color: black;
            	display: inline-block;
            	margin-right: 6px;
        	}
        	.caret-down::before {/* Rotate the caret/arrow icon when clicked on (using JavaScript) */
            	transform: rotate(90deg);
        	}
            .nested { /* Hide the nested list */
                display: none;
            }
            .active { /* Show the nested list when the user clicks on the caret/arrow (with JavaScript) */
                display: block;
            }
            label { /* Style the label */
                cursor: pointer;
            }
            #show_block {
                position: absolute;
                right: 5%;
            }
    	</style>
		</head>
		<body>
		<div id="show_block">
		    <div id="selectors_output"></div>
		    <button type="button" id="copy_clipboard">Copy selectors to clipboard</button>
		</div>
		{{{list_dump}}}
<script>

document.querySelectorAll(".caret").forEach((toggler, index) => {
	// I need anonymous function, not arrow function, to preserve the context
	toggler.addEventListener("click", function() {
		this.parentElement.querySelector(".nested").classList.toggle("active");
		this.classList.toggle("caret-down");
	});
});

document.querySelectorAll("label > input[type=checkbox]").forEach((toggler, index) => {
// I need anonymous function, not arrow function, to preserve the context
	toggler.addEventListener("change", function() {
		document.getElementById("selectors_output").innerHTML = Array
			.from(document.querySelectorAll("label > input[type=checkbox]:checked"))
			.map(x => x.parentElement.textContent).join("<br/>");
	});
});

document.getElementById("copy_clipboard").addEventListener("click", () => {
	let range = document.createRange();
	range.selectNode(document.getElementById("selectors_output"));
	window.getSelection().removeAllRanges(); // clear current selection
	window.getSelection().addRange(range); // to select text
	document.execCommand("copy");
	window.getSelection().removeAllRanges();// to deselect
});
</script>
</body>
</html>
"""

	d = Dict(
		"list_dump" => schema2html(sch, max_vals=max_vals, max_len=max_len),
	)
	return render(tpl, d)
end

function generate_html(file_name, sch::DictEntry; max_vals=100, max_len=1_000)
	s = generate_html(sch; max_vals=max_vals, max_len=max_len)
	open(file_name, "w") do f
 		write(f, s)
	end
end

# Base.show(io, m::MIME{Symbol("text/html")}, sch::JsonGrinder.DictEntry) = print(io, repr(m,sch))

Base.repr(::MIME"text/html", sch::DictEntry; max_vals = 100, max_len=1_000, context = nothing) = generate_html(sch; max_vals=max_vals, max_len=max_len)
Base.showable(::MIME"text/html", ::DictEntry) = true
