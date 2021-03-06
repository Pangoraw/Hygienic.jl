### A Pluto.jl notebook ###
# v0.18.1

using Markdown
using InteractiveUtils

# ╔═╡ d7d4b845-aa4a-4474-a37a-50802a45e6ce
import Pkg

# ╔═╡ c93316ed-62b4-4183-a824-c45d2be09dff
module MyModule
    using Hygienic

    module_value = :magic_module_value
    macro my_macro(x)
        @hygienize quote
            $(esc(x)) = $(QuoteNode(module_value))
        end
    end
end

# ╔═╡ af463c18-e808-4228-af5b-5ae4b49cac98
read("../README.md", String) |> Markdown.parse

# ╔═╡ ee64697c-fc22-466d-9249-43e720eb4fe0
md"""
## Pluto package manager tricks for this test notebook
"""

# ╔═╡ 0bd507f0-a183-11ec-2252-3fd74991bba4
begin
	import Pluto: ReactiveNode, ExpressionExplorer
	import PlutoTest, Test
	import PlutoLinks: @revise
end

# ╔═╡ 52448f61-0ef7-4ac9-909d-2ca3e2841851
begin
	# we use the pkg_str macro here to keep using the Pluto package manager.
	Pkg.pkg"develop .."

	@revise using Hygienic
end

# ╔═╡ edc472b6-be97-403b-95df-0e24b1f3b320
md"""
## A Simple testset implementation

While waiting for [PlutoTest#17](https://github.com/JuliaPluto/PlutoTest.jl).
"""

# ╔═╡ 191512e4-c25f-4b35-b5ed-17943f5f0c54
macro dummy_testset(name, block)
	results = []
	map!(block.args, block.args) do ex
		if !Meta.isexpr(ex, :macrocall) || ex.args[1] != Symbol("@test")
			return ex
		end
		new_name = gensym(:result)
		push!(results, new_name)
		Expr(:local, Expr(:(=), new_name, ex))
	end
	quote
		$(esc(block))
		TestSet($(esc(name)), $(esc(Expr(:vect, results...))))
	end
end

# ╔═╡ 8c0869cd-a59c-4d92-99f7-c18a9752a002
struct TestSet
	name::String

	results::Vector
end

# ╔═╡ c2833c1d-7c48-4dd1-97cd-fbb3457a34d6
function Base.show(io::IO, m::MIME"text/html", ts::TestSet)
	text = md"""
	###### $(ts.name)
	"""
	show(io, m, text)
	for result in ts.results
		show(io, m, result)
	end
end

# ╔═╡ f1e61118-d1ad-4c05-9c24-6b10102084f0
md"""
## Assign the macros depending on whether or not we are in Pluto or not

The PlutoTest test checks for `isdefined(Main, :PlutoRunner)` which is the case in this test case because we are using Pluto inside the tests.
"""

# ╔═╡ 0be72453-abc1-46e5-aac4-c41cf99f731f
is_pluto = startswith(string(nameof(@__MODULE__)), "workspace#")

# ╔═╡ acbf4573-3f77-4a7a-8945-0403ee7daa2e
var"@testset" = is_pluto ? var"@dummy_testset" : Test.var"@testset"

# ╔═╡ ccbdb97b-bd12-4040-969b-c62c8169903c
var"@test" = is_pluto ? 
	PlutoTest.var"@test" : Test.var"@test"

# ╔═╡ 3522296b-adaf-41a0-abe2-8256ab27115b
@dummy_testset "A Test set" begin
	@test 1 + 1 == 2
    @test -cos(π) == 1.
end

# ╔═╡ 87d5721d-7909-464e-932d-b8beb105ca23
md"""
## The actual tests
"""

# ╔═╡ 8b1bd9e5-2783-4bdc-9976-3bf4355ab31f
rnode = ReactiveNode ∘ ExpressionExplorer.try_compute_symbolreferences;

# ╔═╡ 611b1029-7beb-48db-a888-239fe3b80e95
@testset "Test 1" begin
	@test :x ∉ rnode(@hygienize quote
		x = 1
	end).definitions
end

# ╔═╡ 115ccb93-5a61-420c-b88d-2c1261b4eb85
@testset "Another one" begin
	@test :x ∉ rnode(@hygienize quote
		x = 1
	end).references
end

# ╔═╡ bebf115e-fa32-4bc0-84c6-a1244c606b27
@testset "Test 2" begin
	@test :y ∈ rnode(@hygienize quote
		x = 1
		y + x
	end).references
end

# ╔═╡ 5d9caed8-1860-4c58-a09d-1191ae8374f7
macro a()
    @hygienize quote
        x = :a
    end
end

# ╔═╡ 58e3db66-d015-4adf-a36e-cee2852c90c3
macro b()
    quote
        x = :b
        @a()
        if x == :a
            error("x is :a")
        end
        x
    end
end

# ╔═╡ 38fcaa73-8644-4eb0-ada6-6148dd0144f5
@testset "Macro stacking" begin
	@test @b() == :b
end

# ╔═╡ 53496afd-2e53-451a-a2f2-65b2c956dfdb
let
    @MyModule.my_macro(x)

    @testset "Macro interpolation" begin
		@test x == :magic_module_value
	end
end

# ╔═╡ 95c9aaef-4e46-405e-9fef-ee1507c35dff
let
   ex = @hygienize quote
	  x, y = t
	  x + y
   end
	x, y = ex.args[2].args[1].args
	
   node = rnode(ex)
   @testset "Simple expr" begin
	   @test x ∈ node.definitions
	   @test x ∉ node.references
	   @test y ∈ node.definitions
	   @test y ∉ node.references
   end
end

# ╔═╡ 60198b32-c2c5-4d61-9aad-dffb58b8ed41
let
	local ex = @hygienize quote 
		x = 1
		x + y
	end
	x, y = ex.args[4].args[2:end]
	node = rnode(ex)

	@testset "Another simple expr" begin
		@test x ∈ node.definitions
		@test :y ∈ node.references
		@test y == :y
	end
end

# ╔═╡ 192ece6e-18f9-4538-a9ed-840f8c7a7fae
md"""
### Utils
"""

# ╔═╡ 40e5018b-cef4-4dbb-8d92-3b7b5fa6bac9
"""
	unsymify(s::Symbol)

Turn a gensymed symbol into its unsymed counterpart.

```julia
unsymify(gensym(:x)) == :x
```
"""
function unsymify(s::Symbol)
	s = string(s)[3:end]
	split(s, "#") |> first |> Symbol
end

# ╔═╡ 8a56cbc4-ba35-41a3-b25d-69b9595dbddb
let
	@testset "Macro Call" begin
		local ex = @hygienize quote
			state, set_state = blahblah()
			@use_effect([state,]) do
				set_state(y)
			end
			set_state(state)		
		end

		@test ex.args[2].args[1].args[1] |> unsymify == :state
		@test ex.args[2].args[1].args[2] |> unsymify == :set_state
		@test ex.args[end].args[1] |> unsymify == :set_state
		@test ex.args[end].args[2] |> unsymify == :state
	end
end

# ╔═╡ 33a54530-7219-44c2-8f8d-f1afe295517b
@testset "Selector" begin
	local ex = @hygienize quote
		A = blahblah()

		A.B.C
		B.C.D
	end

	@test ex.args[end-2].args[1].args[1] |> unsymify == :A
	@test ex.args[end].args[1].args[1] == :B
end

# ╔═╡ e033d308-070e-4114-8ad2-b3eb5a6929de
@testset "Vect/Tuple" begin
	local ex = @hygienize quote
		x, y, z = 1:3

		[x,y,z]
		(x,y,z)
	end

	@test ex.args[4].args .|> unsymify == [:x, :y, :z]
	@test ex.args[end].args .|> unsymify == [:x, :y, :z]
end

# ╔═╡ e967a1f8-9fe4-4c5f-94f8-bed03ca8046a
@testset "Unsymify" begin
	@test unsymify(gensym(:x)) == :x
end

# ╔═╡ 00000000-0000-0000-0000-000000000001
PLUTO_PROJECT_TOML_CONTENTS = """
[deps]
Hygienic = "60a53d29-03fa-4035-8e80-3746437aa372"
Pkg = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"
Pluto = "c3e4b0f8-55cb-11ea-2926-15256bba5781"
PlutoLinks = "0ff47ea0-7a50-410d-8455-4348d5de0420"
PlutoTest = "cb4044da-4d16-4ffa-a6a3-8cad7f73ebdc"
Test = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[compat]
Hygienic = "~0.0.1"
Pluto = "~0.18.1"
PlutoLinks = "~0.1.5"
PlutoTest = "~0.2.2"
"""

# ╔═╡ 00000000-0000-0000-0000-000000000002
PLUTO_MANIFEST_TOML_CONTENTS = """
# This file is machine-generated - editing it directly is not advised

julia_version = "1.7.1"
manifest_format = "2.0"

[[deps.ArgTools]]
uuid = "0dad84c5-d112-42e6-8d28-ef12dabb789f"

[[deps.Artifacts]]
uuid = "56f22d72-fd6d-98f1-02f0-08ddc0907c33"

[[deps.Base64]]
uuid = "2a0f44e3-6c83-55bd-87e4-b1978d98bd5f"

[[deps.CodeTracking]]
deps = ["InteractiveUtils", "UUIDs"]
git-tree-sha1 = "759a12cefe1cd1bb49e477bc3702287521797483"
uuid = "da1fd8a2-8d9e-5ec2-8556-3022fb5608a2"
version = "1.0.7"

[[deps.CompilerSupportLibraries_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "e66e0078-7015-5450-92f7-15fbd957f2ae"

[[deps.Configurations]]
deps = ["ExproniconLite", "OrderedCollections", "TOML"]
git-tree-sha1 = "ab9b7c51e8acdd20c769bccde050b5615921c533"
uuid = "5218b696-f38b-4ac9-8b61-a12ec717816d"
version = "0.17.3"

[[deps.DataAPI]]
git-tree-sha1 = "cc70b17275652eb47bc9e5f81635981f13cea5c8"
uuid = "9a962f9c-6df0-11e9-0e5d-c546b8b5ee8a"
version = "1.9.0"

[[deps.DataValueInterfaces]]
git-tree-sha1 = "bfc1187b79289637fa0ef6d4436ebdfe6905cbd6"
uuid = "e2d170a0-9d28-54be-80f0-106bbe20a464"
version = "1.0.0"

[[deps.Dates]]
deps = ["Printf"]
uuid = "ade2ca70-3891-5945-98fb-dc099432e06a"

[[deps.Distributed]]
deps = ["Random", "Serialization", "Sockets"]
uuid = "8ba89e20-285c-5b6f-9357-94700520ee1b"

[[deps.Downloads]]
deps = ["ArgTools", "LibCURL", "NetworkOptions"]
uuid = "f43a241f-c20a-4ad4-852c-f6b1247861c6"

[[deps.ExproniconLite]]
git-tree-sha1 = "8b08cc88844e4d01db5a2405a08e9178e19e479e"
uuid = "55351af7-c7e9-48d6-89ff-24e801d99491"
version = "0.6.13"

[[deps.FileWatching]]
uuid = "7b1f6079-737a-58dc-b8bc-7a2ca5c1b5ee"

[[deps.FuzzyCompletions]]
deps = ["REPL"]
git-tree-sha1 = "efd6c064e15e92fcce436977c825d2117bf8ce76"
uuid = "fb4132e2-a121-4a70-b8a1-d5b831dcdcc2"
version = "0.5.0"

[[deps.HTTP]]
deps = ["Base64", "Dates", "IniFile", "Logging", "MbedTLS", "NetworkOptions", "Sockets", "URIs"]
git-tree-sha1 = "0fa77022fe4b511826b39c894c90daf5fce3334a"
uuid = "cd3eb016-35fb-5094-929b-558a96fad6f3"
version = "0.9.17"

[[deps.Hygienic]]
path = "../../home/paul/Projects/Hygienic.jl"
uuid = "60a53d29-03fa-4035-8e80-3746437aa372"
version = "0.0.1"

[[deps.HypertextLiteral]]
git-tree-sha1 = "2b078b5a615c6c0396c77810d92ee8c6f470d238"
uuid = "ac1192a8-f4b3-4bfe-ba22-af5b92cd3ab2"
version = "0.9.3"

[[deps.IniFile]]
git-tree-sha1 = "f550e6e32074c939295eb5ea6de31849ac2c9625"
uuid = "83e8ac13-25f8-5344-8a64-a9f2b223428f"
version = "0.5.1"

[[deps.InteractiveUtils]]
deps = ["Markdown"]
uuid = "b77e0a4c-d291-57a0-90e8-8db25a27a240"

[[deps.IteratorInterfaceExtensions]]
git-tree-sha1 = "a3f24677c21f5bbe9d2a714f95dcd58337fb2856"
uuid = "82899510-4779-5014-852e-03e436cf321d"
version = "1.0.0"

[[deps.JuliaInterpreter]]
deps = ["CodeTracking", "InteractiveUtils", "Random", "UUIDs"]
git-tree-sha1 = "007ab1efbda85da785caf1943d401a6e7556fc9a"
uuid = "aa1ae85d-cabe-5617-a682-6adf51b2e16a"
version = "0.9.9"

[[deps.LibCURL]]
deps = ["LibCURL_jll", "MozillaCACerts_jll"]
uuid = "b27032c2-a3e7-50c8-80cd-2d36dbcbfd21"

[[deps.LibCURL_jll]]
deps = ["Artifacts", "LibSSH2_jll", "Libdl", "MbedTLS_jll", "Zlib_jll", "nghttp2_jll"]
uuid = "deac9b47-8bc7-5906-a0fe-35ac56dc84c0"

[[deps.LibGit2]]
deps = ["Base64", "NetworkOptions", "Printf", "SHA"]
uuid = "76f85450-5226-5b5a-8eaa-529ad045b433"

[[deps.LibSSH2_jll]]
deps = ["Artifacts", "Libdl", "MbedTLS_jll"]
uuid = "29816b5a-b9ab-546f-933c-edad1886dfa8"

[[deps.Libdl]]
uuid = "8f399da3-3557-5675-b5ff-fb832c97cbdb"

[[deps.LinearAlgebra]]
deps = ["Libdl", "libblastrampoline_jll"]
uuid = "37e2e46d-f89d-539d-b4ee-838fcccc9c8e"

[[deps.Logging]]
uuid = "56ddb016-857b-54e1-b83d-db4d58db5568"

[[deps.LoweredCodeUtils]]
deps = ["JuliaInterpreter"]
git-tree-sha1 = "6b0440822974cab904c8b14d79743565140567f6"
uuid = "6f1432cf-f94c-5a45-995e-cdbf5db27b0b"
version = "2.2.1"

[[deps.Markdown]]
deps = ["Base64"]
uuid = "d6f4376e-aef5-505a-96c1-9c027394607a"

[[deps.MbedTLS]]
deps = ["Dates", "MbedTLS_jll", "Random", "Sockets"]
git-tree-sha1 = "1c38e51c3d08ef2278062ebceade0e46cefc96fe"
uuid = "739be429-bea8-5141-9913-cc70e7f3736d"
version = "1.0.3"

[[deps.MbedTLS_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "c8ffd9c3-330d-5841-b78e-0817d7145fa1"

[[deps.MozillaCACerts_jll]]
uuid = "14a3606d-f60d-562e-9121-12d972cd8159"

[[deps.MsgPack]]
deps = ["Serialization"]
git-tree-sha1 = "a8cbf066b54d793b9a48c5daa5d586cf2b5bd43d"
uuid = "99f44e22-a591-53d1-9472-aa23ef4bd671"
version = "1.1.0"

[[deps.NetworkOptions]]
uuid = "ca575930-c2e3-43a9-ace4-1e988b2c1908"

[[deps.OpenBLAS_jll]]
deps = ["Artifacts", "CompilerSupportLibraries_jll", "Libdl"]
uuid = "4536629a-c528-5b80-bd46-f80d51c5b363"

[[deps.OrderedCollections]]
git-tree-sha1 = "85f8e6578bf1f9ee0d11e7bb1b1456435479d47c"
uuid = "bac558e1-5e72-5ebc-8fee-abe8a469f55d"
version = "1.4.1"

[[deps.Pkg]]
deps = ["Artifacts", "Dates", "Downloads", "LibGit2", "Libdl", "Logging", "Markdown", "Printf", "REPL", "Random", "SHA", "Serialization", "TOML", "Tar", "UUIDs", "p7zip_jll"]
uuid = "44cfe95a-1eb2-52ea-b672-e2afdf69b78f"

[[deps.Pluto]]
deps = ["Base64", "Configurations", "Dates", "Distributed", "FileWatching", "FuzzyCompletions", "HTTP", "InteractiveUtils", "Logging", "Markdown", "MsgPack", "Pkg", "REPL", "RelocatableFolders", "Sockets", "Tables", "UUIDs"]
git-tree-sha1 = "c97f4548e903d132342a6f5998554f507d0b2578"
uuid = "c3e4b0f8-55cb-11ea-2926-15256bba5781"
version = "0.18.1"

[[deps.PlutoHooks]]
deps = ["InteractiveUtils", "Markdown", "UUIDs"]
git-tree-sha1 = "072cdf20c9b0507fdd977d7d246d90030609674b"
uuid = "0ff47ea0-7a50-410d-8455-4348d5de0774"
version = "0.0.5"

[[deps.PlutoLinks]]
deps = ["FileWatching", "InteractiveUtils", "Markdown", "PlutoHooks", "Revise", "UUIDs"]
git-tree-sha1 = "0e8bcc235ec8367a8e9648d48325ff00e4b0a545"
uuid = "0ff47ea0-7a50-410d-8455-4348d5de0420"
version = "0.1.5"

[[deps.PlutoTest]]
deps = ["HypertextLiteral", "InteractiveUtils", "Markdown", "Test"]
git-tree-sha1 = "17aa9b81106e661cffa1c4c36c17ee1c50a86eda"
uuid = "cb4044da-4d16-4ffa-a6a3-8cad7f73ebdc"
version = "0.2.2"

[[deps.Printf]]
deps = ["Unicode"]
uuid = "de0858da-6303-5e67-8744-51eddeeeb8d7"

[[deps.REPL]]
deps = ["InteractiveUtils", "Markdown", "Sockets", "Unicode"]
uuid = "3fa0cd96-eef1-5676-8a61-b3b8758bbffb"

[[deps.Random]]
deps = ["SHA", "Serialization"]
uuid = "9a3f8284-a2c9-5f02-9a11-845980a1fd5c"

[[deps.RelocatableFolders]]
deps = ["SHA", "Scratch"]
git-tree-sha1 = "cdbd3b1338c72ce29d9584fdbe9e9b70eeb5adca"
uuid = "05181044-ff0b-4ac5-8273-598c1e38db00"
version = "0.1.3"

[[deps.Requires]]
deps = ["UUIDs"]
git-tree-sha1 = "838a3a4188e2ded87a4f9f184b4b0d78a1e91cb7"
uuid = "ae029012-a4dd-5104-9daa-d747884805df"
version = "1.3.0"

[[deps.Revise]]
deps = ["CodeTracking", "Distributed", "FileWatching", "JuliaInterpreter", "LibGit2", "LoweredCodeUtils", "OrderedCollections", "Pkg", "REPL", "Requires", "UUIDs", "Unicode"]
git-tree-sha1 = "4d4239e93531ac3e7ca7e339f15978d0b5149d03"
uuid = "295af30f-e4ad-537b-8983-00126c2a3abe"
version = "3.3.3"

[[deps.SHA]]
uuid = "ea8e919c-243c-51af-8825-aaa63cd721ce"

[[deps.Scratch]]
deps = ["Dates"]
git-tree-sha1 = "0b4b7f1393cff97c33891da2a0bf69c6ed241fda"
uuid = "6c6a2e73-6563-6170-7368-637461726353"
version = "1.1.0"

[[deps.Serialization]]
uuid = "9e88b42a-f829-5b0c-bbe9-9e923198166b"

[[deps.Sockets]]
uuid = "6462fe0b-24de-5631-8697-dd941f90decc"

[[deps.TOML]]
deps = ["Dates"]
uuid = "fa267f1f-6049-4f14-aa54-33bafae1ed76"

[[deps.TableTraits]]
deps = ["IteratorInterfaceExtensions"]
git-tree-sha1 = "c06b2f539df1c6efa794486abfb6ed2022561a39"
uuid = "3783bdb8-4a98-5b6b-af9a-565f29a5fe9c"
version = "1.0.1"

[[deps.Tables]]
deps = ["DataAPI", "DataValueInterfaces", "IteratorInterfaceExtensions", "LinearAlgebra", "OrderedCollections", "TableTraits", "Test"]
git-tree-sha1 = "5ce79ce186cc678bbb5c5681ca3379d1ddae11a1"
uuid = "bd369af6-aec1-5ad0-b16a-f7cc5008161c"
version = "1.7.0"

[[deps.Tar]]
deps = ["ArgTools", "SHA"]
uuid = "a4e569a6-e804-4fa4-b0f3-eef7a1d5b13e"

[[deps.Test]]
deps = ["InteractiveUtils", "Logging", "Random", "Serialization"]
uuid = "8dfed614-e22c-5e08-85e1-65c5234f0b40"

[[deps.URIs]]
git-tree-sha1 = "97bbe755a53fe859669cd907f2d96aee8d2c1355"
uuid = "5c2747f8-b7ea-4ff2-ba2e-563bfd36b1d4"
version = "1.3.0"

[[deps.UUIDs]]
deps = ["Random", "SHA"]
uuid = "cf7118a7-6976-5b1a-9a39-7adc72f591a4"

[[deps.Unicode]]
uuid = "4ec0a83e-493e-50e2-b9ac-8f72acf5a8f5"

[[deps.Zlib_jll]]
deps = ["Libdl"]
uuid = "83775a58-1f1d-513f-b197-d71354ab007a"

[[deps.libblastrampoline_jll]]
deps = ["Artifacts", "Libdl", "OpenBLAS_jll"]
uuid = "8e850b90-86db-534c-a0d3-1478176c7d93"

[[deps.nghttp2_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "8e850ede-7688-5339-a07c-302acd2aaf8d"

[[deps.p7zip_jll]]
deps = ["Artifacts", "Libdl"]
uuid = "3f19e933-33d8-53b3-aaab-bd5110c3b7a0"
"""

# ╔═╡ Cell order:
# ╟─af463c18-e808-4228-af5b-5ae4b49cac98
# ╟─ee64697c-fc22-466d-9249-43e720eb4fe0
# ╠═d7d4b845-aa4a-4474-a37a-50802a45e6ce
# ╠═0bd507f0-a183-11ec-2252-3fd74991bba4
# ╠═52448f61-0ef7-4ac9-909d-2ca3e2841851
# ╟─edc472b6-be97-403b-95df-0e24b1f3b320
# ╠═191512e4-c25f-4b35-b5ed-17943f5f0c54
# ╟─3522296b-adaf-41a0-abe2-8256ab27115b
# ╠═8c0869cd-a59c-4d92-99f7-c18a9752a002
# ╠═c2833c1d-7c48-4dd1-97cd-fbb3457a34d6
# ╟─f1e61118-d1ad-4c05-9c24-6b10102084f0
# ╠═0be72453-abc1-46e5-aac4-c41cf99f731f
# ╠═acbf4573-3f77-4a7a-8945-0403ee7daa2e
# ╠═ccbdb97b-bd12-4040-969b-c62c8169903c
# ╟─87d5721d-7909-464e-932d-b8beb105ca23
# ╠═8b1bd9e5-2783-4bdc-9976-3bf4355ab31f
# ╟─611b1029-7beb-48db-a888-239fe3b80e95
# ╟─115ccb93-5a61-420c-b88d-2c1261b4eb85
# ╟─bebf115e-fa32-4bc0-84c6-a1244c606b27
# ╠═5d9caed8-1860-4c58-a09d-1191ae8374f7
# ╠═58e3db66-d015-4adf-a36e-cee2852c90c3
# ╟─38fcaa73-8644-4eb0-ada6-6148dd0144f5
# ╠═c93316ed-62b4-4183-a824-c45d2be09dff
# ╟─53496afd-2e53-451a-a2f2-65b2c956dfdb
# ╟─95c9aaef-4e46-405e-9fef-ee1507c35dff
# ╟─60198b32-c2c5-4d61-9aad-dffb58b8ed41
# ╟─8a56cbc4-ba35-41a3-b25d-69b9595dbddb
# ╟─33a54530-7219-44c2-8f8d-f1afe295517b
# ╟─e033d308-070e-4114-8ad2-b3eb5a6929de
# ╟─192ece6e-18f9-4538-a9ed-840f8c7a7fae
# ╟─40e5018b-cef4-4dbb-8d92-3b7b5fa6bac9
# ╟─e967a1f8-9fe4-4c5f-94f8-bed03ca8046a
# ╟─00000000-0000-0000-0000-000000000001
# ╟─00000000-0000-0000-0000-000000000002
