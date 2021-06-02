--
-- RSA Encryption/Decryption Library
-- By 1lann
--
-- Refer to license: http://pastebin.com/9gWSyqQt
--
-- See gists comment at the bottom of the page for FAQ and updates!
--

--
-- Start of third-party libraries/helpers
--

-- two functions to help make Lua act more like C
local function fl(x)
	if x < 0 then
		return math.ceil(x) + 0 -- make -0 go away
	else
		return math.floor(x)
	end
end

local function cmod(a, b)
	local x = a % b
	if a < 0 and x > 0 then
		x = x - b
	end
	return x
end


local radix = 2^24 -- maybe up to 2^26 is safe?
local radix_sqrt = fl(math.sqrt(radix))

local bigintmt -- forward decl

local function alloc()
	local bi = {}
	setmetatable(bi, bigintmt)
	bi.comps = {}
	bi.sign = 1;
	return bi
end

local function clone(a)
	local bi = alloc()
	bi.sign = a.sign
	local c = bi.comps
	local ac = a.comps
	for i = 1, #ac do
		c[i] = ac[i]
	end
	return bi
end

local function normalize(bi, notrunc)
	local c = bi.comps
	local v
	-- borrow for negative components
	for i = 1, #c - 1 do
		v = c[i]
		if v < 0 then
			c[i+1] = c[i+1] + fl(v / radix) - 1
			v = cmod(v, radix)
			if v ~= 0 then
				c[i] = v + radix
			else
				c[i] = v
				c[i+1] = c[i+1] + 1
			end
		end
	end
	-- is top component negative?
	if c[#c] < 0 then
		-- switch the sign and fix components
		bi.sign = -bi.sign
		for i = 1, #c - 1 do
			v = c[i]
			c[i] = radix - v
			c[i+1] = c[i+1] + 1
		end
		c[#c] = -c[#c]
	end
	-- carry for components larger than radix
	for i = 1, #c do
		v = c[i]
		if v > radix then
			c[i+1] = (c[i+1] or 0) + fl(v / radix)
			c[i] = cmod(v, radix)
		end
	end
	-- trim off leading zeros
	if not notrunc then
		for i = #c, 2, -1 do
			if c[i] == 0 then
				c[i] = nil
			else
				break
			end
		end
	end
	-- check for -0
	if #c == 1 and c[1] == 0 and bi.sign == -1 then
		bi.sign = 1
	end
end

local function negate(a)
	local bi = clone(a)
	bi.sign = -bi.sign
	return bi
end

local function compare(a, b)
	local ac, bc = a.comps, b.comps
	local as, bs = a.sign, b.sign
	if ac == bc then
		return 0
	elseif as > bs then
		return 1
	elseif as < bs then
		return -1
	elseif #ac > #bc then
		return as
	elseif #ac < #bc then
		return -as
	end
	for i = #ac, 1, -1 do
		if ac[i] > bc[i] then
			return as
		elseif ac[i] < bc[i] then
			return -as
		end
	end
	return 0
end

local function lt(a, b)
	return compare(a, b) < 0
end

local function eq(a, b)
	return compare(a, b) == 0
end

local function le(a, b)
	return compare(a, b) <= 0
end

local function addint(a, n)
	local bi = clone(a)
	if bi.sign == 1 then
		bi.comps[1] = bi.comps[1] + n
	else
		bi.comps[1] = bi.comps[1] - n
	end
	normalize(bi)
	return bi
end

local function add(a, b)
	if type(a) == "number" then
		return addint(b, a)
	elseif type(b) == "number" then
		return addint(a, b)
	end
	local bi = clone(a)
	local sign = bi.sign == b.sign
	local c = bi.comps
	for i = #c + 1, #b.comps do
		c[i] = 0
	end
	local bc = b.comps
	for i = 1, #bc do
		local v = bc[i]
		if sign then
			c[i] = c[i] + v
		else
			c[i] = c[i] - v
		end
	end
	normalize(bi)
	return bi
end

local function sub(a, b)
	if type(b) == "number" then
		return addint(a, -b)
	elseif type(a) == "number" then
		a = bigint(a)
	end
	return add(a, negate(b))
end

local function mulint(a, b)
	local bi = clone(a)
	if b < 0 then
		b = -b
		bi.sign = -bi.sign
	end
	local bc = bi.comps
	for i = 1, #bc do
		bc[i] = bc[i] * b
	end
	normalize(bi)
	return bi
end

local function multiply(a, b)
	local bi = alloc()
	local c = bi.comps
	local ac, bc = a.comps, b.comps
	for i = 1, #ac + #bc do
		c[i] = 0
	end
	for i = 1, #ac do
		for j = 1, #bc do
			c[i+j-1] = c[i+j-1] + ac[i] * bc[j]
		end
		-- keep the zeroes
		normalize(bi, true)
	end
	normalize(bi)
	if bi ~= bigint(0) then
		bi.sign = a.sign * b.sign
	end
	return bi
end

local function kmul(a, b)
	local ac, bc = a.comps, b.comps
	local an, bn = #a.comps, #b.comps
	local bi, bj, bk, bl = alloc(), alloc(), alloc(), alloc()
	local ic, jc, kc, lc = bi.comps, bj.comps, bk.comps, bl.comps

	local n = fl((math.max(an, bn) + 1) / 2)
	for i = 1, n do
		ic[i] = (i + n <= an) and ac[i+n] or 0
		jc[i] = (i <= an) and ac[i] or 0
		kc[i] = (i + n <= bn) and bc[i+n] or 0
		lc[i] = (i <= bn) and bc[i] or 0
	end
	normalize(bi)
	normalize(bj)
	normalize(bk)
	normalize(bl)
	local ik = bi * bk
	local jl = bj * bl
	local mid = (bi + bj) * (bk + bl) - ik - jl
	local mc = mid.comps
	local ikc = ik.comps
	local jlc = jl.comps
	for i = 1, #ikc + n*2 do -- fill it up
		jlc[i] = jlc[i] or 0
	end
	for i = 1, #mc do
		jlc[i+n] = jlc[i+n] + mc[i]
	end
	for i = 1, #ikc do
		jlc[i+n*2] = jlc[i+n*2] + ikc[i]
	end
	jl.sign = a.sign * b.sign
	normalize(jl)
	return jl
end

local kthresh = 12

local function mul(a, b)
	if type(a) == "number" then
		return mulint(b, a)
	elseif type(b) == "number" then
		return mulint(a, b)
	end
	if #a.comps < kthresh or #b.comps < kthresh then
		return multiply(a, b)
	end
	return kmul(a, b)
end

local function divint(numer, denom)
	local bi = clone(numer)
	if denom < 0 then
		denom = -denom
		bi.sign = -bi.sign
	end
	local r = 0
	local c = bi.comps
	for i = #c, 1, -1 do
		r = r * radix + c[i]
		c[i] = fl(r / denom)
		r = cmod(r, denom)
	end
	normalize(bi)
	return bi
end

local function multi_divide(numer, denom)
	local n = #denom.comps
	local approx = divint(numer, denom.comps[n])
	for i = n, #approx.comps do
		approx.comps[i - n + 1] = approx.comps[i]
	end
	for i = #approx.comps, #approx.comps - n + 2, -1 do
		approx.comps[i] = nil
	end
	local rem = approx * denom - numer
	if rem < denom then
		quotient = approx
	else
		quotient = approx - multi_divide(rem, denom)
	end
	return quotient
end

local function multi_divide_wrap(numer, denom)
	-- we use a successive approximation method, but it doesn't work
	-- if the high order component is too small.  adjust if needed.
	if denom.comps[#denom.comps] < radix_sqrt then
		numer = mulint(numer, radix_sqrt)
		denom = mulint(denom, radix_sqrt)
	end
	return multi_divide(numer, denom)
end

local function div(numer, denom)
	if type(denom) == "number" then
		if denom == 0 then
			error("divide by 0", 2)
		end
		return divint(numer, denom)
	elseif type(numer) == "number" then
		numer = bigint(numer)
	end
	-- check signs and trivial cases
	local sign = 1
	local cmp = compare(denom, bigint(0))
	if cmp == 0 then
		error("divide by 0", 2)
	elseif cmp == -1 then
		sign = -sign
		denom = negate(denom)
	end
	cmp = compare(numer, bigint(0))
	if cmp == 0 then
		return bigint(0)
	elseif cmp == -1 then
		sign = -sign
		numer = negate(numer)
	end
	cmp = compare(numer, denom)
	if cmp == -1 then
		return bigint(0)
	elseif cmp == 0 then
		return bigint(sign)
	end
	local bi
	-- if small enough, do it the easy way
	if #denom.comps == 1 then
		bi = divint(numer, denom.comps[1])
	else
		bi = multi_divide_wrap(numer, denom)
	end
	if sign == -1 then
		bi = negate(bi)
	end
	return bi
end

local function intrem(bi, m)
	if m < 0 then
		m = -m
	end
	local rad_r = 1
	local r = 0
	local bc = bi.comps
	for i = 1, #bc do
		local v = bc[i]
		r = cmod(r + v * rad_r, m)
		rad_r = cmod(rad_r * radix, m)
	end
	if bi.sign < 1 then
		r = -r
	end
	return r
end

local function intmod(bi, m)
	local r = intrem(bi, m)
	if r < 0 then
		r = r + m
	end
	return r
end

local function rem(bi, m)
	if type(m) == "number" then
		return bigint(intrem(bi, m))
	elseif type(bi) == "number" then
		bi = bigint(bi)
	end

	return bi - ((bi / m) * m)
end

local function mod(a, m)
	local bi = rem(a, m)
	if bi.sign == -1 then
		bi = bi + m
	end
	return bi
end

local printscale = 10000000
local printscalefmt = string.format("%%.%dd", math.log10(printscale))
local function makestr(bi, s)
	if bi >= bigint(printscale) then
		makestr(divint(bi, printscale), s)
	end
	table.insert(s, string.format(printscalefmt, intmod(bi, printscale)))
end

local function biginttostring(bi)
	local s = {}
	if bi < bigint(0) then
		bi = negate(bi)
		table.insert(s, "-")
	end
	makestr(bi, s)
	s = table.concat(s):gsub("^0*", "")
	if s == "" then s = "0" end
	return s
end

local function biginttonumber(bi)
	return tonumber(biginttostring(bi))
end

bigintmt = {
	__add = add,
	__sub = sub,
	__mul = mul,
	__div = div,
	__mod = mod,
	__unm = negate,
	__eq = eq,
	__lt = lt,
	__le = le,
	__tostring = biginttostring,
}

local cache = {}
local ncache = 0

function bigint(n)
	if cache[n] then
		return cache[n]
	end
	local bi
	if type(n) == "string" then
		local digits = { n:byte(1, -1) }
		for i = 1, #digits do
			digits[i] = string.char(digits[i])
		end
		local start = 1
		local sign = 1
		if digits[i] == '-' then
			sign = -1
			start = 2
		end
		bi = bigint(0)
		for i = start, #digits do
			bi = addint(mulint(bi, 10), tonumber(digits[i]))
		end
		bi = mulint(bi, sign)
	else
		bi = alloc()
		bi.comps[1] = n
		normalize(bi)
	end
	if ncache > 100 then
		cache = {}
		ncache = 0
	end
	cache[n] = bi
	ncache = ncache + 1
	return bi
end

--
-- Start of my code
--

local powersTwo = {
bigint("2"),
bigint("4"),
bigint("8"),
bigint("16"),
bigint("32"),
bigint("64"),
bigint("128"),
bigint("256"),
bigint("512"),
bigint("1024"),
bigint("2048"),
bigint("4096"),
bigint("8192"),
bigint("16384"),
bigint("32768"),
bigint("65536"),
bigint("131072"),
bigint("262144"),
bigint("524288"),
bigint("1048576"),
bigint("2097152"),
bigint("4194304"),
bigint("8388608"),
bigint("16777216"),
bigint("33554432"),
bigint("67108864"),
bigint("134217728"),
bigint("268435456"),
bigint("536870912"),
bigint("1073741824"),
bigint("2147483648"),
bigint("4294967296"),
bigint("8589934592"),
bigint("17179869184"),
bigint("34359738368"),
bigint("68719476736"),
bigint("137438953472"),
bigint("274877906944"),
bigint("549755813888"),
bigint("1099511627776"),
bigint("2199023255552"),
bigint("4398046511104"),
bigint("8796093022208"),
bigint("17592186044416"),
bigint("35184372088832"),
bigint("70368744177664"),
bigint("140737488355328"),
bigint("281474976710656"),
bigint("562949953421312"),
bigint("1125899906842624"),
bigint("2251799813685248"),
bigint("4503599627370496"),
bigint("9007199254740992"),
bigint("18014398509481984"),
bigint("36028797018963968"),
bigint("72057594037927936"),
bigint("144115188075855872"),
bigint("288230376151711744"),
bigint("576460752303423488"),
bigint("1152921504606846976"),
bigint("2305843009213693952"),
bigint("4611686018427387904"),
bigint("9223372036854775808"),
bigint("18446744073709551616"),
bigint("36893488147419103232"),
bigint("73786976294838206464"),
bigint("147573952589676412928"),
bigint("295147905179352825856"),
bigint("590295810358705651712"),
bigint("1180591620717411303424"),
bigint("2361183241434822606848"),
bigint("4722366482869645213696"),
bigint("9444732965739290427392"),
bigint("18889465931478580854784"),
bigint("37778931862957161709568"),
bigint("75557863725914323419136"),
bigint("151115727451828646838272"),
bigint("302231454903657293676544"),
bigint("604462909807314587353088"),
bigint("1208925819614629174706176"),
bigint("2417851639229258349412352"),
bigint("4835703278458516698824704"),
bigint("9671406556917033397649408"),
bigint("19342813113834066795298816"),
bigint("38685626227668133590597632"),
bigint("77371252455336267181195264"),
bigint("154742504910672534362390528"),
bigint("309485009821345068724781056"),
bigint("618970019642690137449562112"),
bigint("1237940039285380274899124224"),
bigint("2475880078570760549798248448"),
bigint("4951760157141521099596496896"),
bigint("9903520314283042199192993792"),
bigint("19807040628566084398385987584"),
bigint("39614081257132168796771975168"),
bigint("79228162514264337593543950336"),
bigint("158456325028528675187087900672"),
bigint("316912650057057350374175801344"),
bigint("633825300114114700748351602688"),
bigint("1267650600228229401496703205376"),
bigint("2535301200456458802993406410752"),
bigint("5070602400912917605986812821504"),
bigint("10141204801825835211973625643008"),
bigint("20282409603651670423947251286016"),
bigint("40564819207303340847894502572032"),
bigint("81129638414606681695789005144064"),
bigint("162259276829213363391578010288128"),
bigint("324518553658426726783156020576256"),
bigint("649037107316853453566312041152512"),
bigint("1298074214633706907132624082305024"),
bigint("2596148429267413814265248164610048"),
bigint("5192296858534827628530496329220096"),
bigint("10384593717069655257060992658440192"),
bigint("20769187434139310514121985316880384"),
bigint("41538374868278621028243970633760768"),
bigint("83076749736557242056487941267521536"),
bigint("166153499473114484112975882535043072"),
bigint("332306998946228968225951765070086144"),
bigint("664613997892457936451903530140172288"),
bigint("1329227995784915872903807060280344576"),
bigint("2658455991569831745807614120560689152"),
bigint("5316911983139663491615228241121378304"),
bigint("10633823966279326983230456482242756608"),
bigint("21267647932558653966460912964485513216"),
bigint("42535295865117307932921825928971026432"),
bigint("85070591730234615865843651857942052864"),
bigint("170141183460469231731687303715884105728"),
bigint("340282366920938463463374607431768211456"),
bigint("680564733841876926926749214863536422912"),
bigint("1361129467683753853853498429727072845824"),
bigint("2722258935367507707706996859454145691648"),
bigint("5444517870735015415413993718908291383296"),
bigint("10889035741470030830827987437816582766592"),
bigint("21778071482940061661655974875633165533184"),
bigint("43556142965880123323311949751266331066368"),
bigint("87112285931760246646623899502532662132736"),
bigint("174224571863520493293247799005065324265472"),
bigint("348449143727040986586495598010130648530944"),
bigint("696898287454081973172991196020261297061888"),
bigint("1393796574908163946345982392040522594123776"),
bigint("2787593149816327892691964784081045188247552"),
bigint("5575186299632655785383929568162090376495104"),
bigint("11150372599265311570767859136324180752990208"),
bigint("22300745198530623141535718272648361505980416"),
bigint("44601490397061246283071436545296723011960832"),
bigint("89202980794122492566142873090593446023921664"),
bigint("178405961588244985132285746181186892047843328"),
bigint("356811923176489970264571492362373784095686656"),
bigint("713623846352979940529142984724747568191373312"),
bigint("1427247692705959881058285969449495136382746624"),
bigint("2854495385411919762116571938898990272765493248"),
bigint("5708990770823839524233143877797980545530986496"),
bigint("11417981541647679048466287755595961091061972992"),
bigint("22835963083295358096932575511191922182123945984"),
bigint("45671926166590716193865151022383844364247891968"),
bigint("91343852333181432387730302044767688728495783936"),
bigint("182687704666362864775460604089535377456991567872"),
bigint("365375409332725729550921208179070754913983135744"),
bigint("730750818665451459101842416358141509827966271488"),
bigint("1461501637330902918203684832716283019655932542976"),
bigint("2923003274661805836407369665432566039311865085952"),
bigint("5846006549323611672814739330865132078623730171904"),
bigint("11692013098647223345629478661730264157247460343808"),
bigint("23384026197294446691258957323460528314494920687616"),
bigint("46768052394588893382517914646921056628989841375232"),
bigint("93536104789177786765035829293842113257979682750464"),
bigint("187072209578355573530071658587684226515959365500928"),
bigint("374144419156711147060143317175368453031918731001856"),
bigint("748288838313422294120286634350736906063837462003712"),
bigint("1496577676626844588240573268701473812127674924007424"),
bigint("2993155353253689176481146537402947624255349848014848"),
bigint("5986310706507378352962293074805895248510699696029696"),
bigint("11972621413014756705924586149611790497021399392059392"),
bigint("23945242826029513411849172299223580994042798784118784"),
bigint("47890485652059026823698344598447161988085597568237568"),
bigint("95780971304118053647396689196894323976171195136475136"),
bigint("191561942608236107294793378393788647952342390272950272"),
bigint("383123885216472214589586756787577295904684780545900544"),
bigint("766247770432944429179173513575154591809369561091801088"),
bigint("1532495540865888858358347027150309183618739122183602176"),
bigint("3064991081731777716716694054300618367237478244367204352"),
bigint("6129982163463555433433388108601236734474956488734408704"),
bigint("12259964326927110866866776217202473468949912977468817408"),
bigint("24519928653854221733733552434404946937899825954937634816"),
bigint("49039857307708443467467104868809893875799651909875269632"),
bigint("98079714615416886934934209737619787751599303819750539264"),
bigint("196159429230833773869868419475239575503198607639501078528"),
bigint("392318858461667547739736838950479151006397215279002157056"),
bigint("784637716923335095479473677900958302012794430558004314112"),
bigint("1569275433846670190958947355801916604025588861116008628224"),
bigint("3138550867693340381917894711603833208051177722232017256448"),
bigint("6277101735386680763835789423207666416102355444464034512896"),
bigint("12554203470773361527671578846415332832204710888928069025792"),
bigint("25108406941546723055343157692830665664409421777856138051584"),
bigint("50216813883093446110686315385661331328818843555712276103168"),
bigint("100433627766186892221372630771322662657637687111424552206336"),
bigint("200867255532373784442745261542645325315275374222849104412672"),
bigint("401734511064747568885490523085290650630550748445698208825344"),
bigint("803469022129495137770981046170581301261101496891396417650688"),
bigint("1606938044258990275541962092341162602522202993782792835301376"),
bigint("3213876088517980551083924184682325205044405987565585670602752"),
bigint("6427752177035961102167848369364650410088811975131171341205504"),
bigint("12855504354071922204335696738729300820177623950262342682411008"),
bigint("25711008708143844408671393477458601640355247900524685364822016"),
bigint("51422017416287688817342786954917203280710495801049370729644032"),
bigint("102844034832575377634685573909834406561420991602098741459288064"),
bigint("205688069665150755269371147819668813122841983204197482918576128"),
bigint("411376139330301510538742295639337626245683966408394965837152256"),
bigint("822752278660603021077484591278675252491367932816789931674304512"),
bigint("1645504557321206042154969182557350504982735865633579863348609024"),
bigint("3291009114642412084309938365114701009965471731267159726697218048"),
bigint("6582018229284824168619876730229402019930943462534319453394436096"),
bigint("13164036458569648337239753460458804039861886925068638906788872192"),
bigint("26328072917139296674479506920917608079723773850137277813577744384"),
bigint("52656145834278593348959013841835216159447547700274555627155488768"),
bigint("105312291668557186697918027683670432318895095400549111254310977536"),
bigint("210624583337114373395836055367340864637790190801098222508621955072"),
bigint("421249166674228746791672110734681729275580381602196445017243910144"),
bigint("842498333348457493583344221469363458551160763204392890034487820288"),
bigint("1684996666696914987166688442938726917102321526408785780068975640576"),
bigint("3369993333393829974333376885877453834204643052817571560137951281152"),
bigint("6739986666787659948666753771754907668409286105635143120275902562304"),
bigint("13479973333575319897333507543509815336818572211270286240551805124608"),
bigint("26959946667150639794667015087019630673637144422540572481103610249216"),
bigint("53919893334301279589334030174039261347274288845081144962207220498432"),
bigint("107839786668602559178668060348078522694548577690162289924414440996864"),
bigint("215679573337205118357336120696157045389097155380324579848828881993728"),
bigint("431359146674410236714672241392314090778194310760649159697657763987456"),
bigint("862718293348820473429344482784628181556388621521298319395315527974912"),
bigint("1725436586697640946858688965569256363112777243042596638790631055949824"),
bigint("3450873173395281893717377931138512726225554486085193277581262111899648"),
bigint("6901746346790563787434755862277025452451108972170386555162524223799296"),
bigint("13803492693581127574869511724554050904902217944340773110325048447598592"),
bigint("27606985387162255149739023449108101809804435888681546220650096895197184"),
bigint("55213970774324510299478046898216203619608871777363092441300193790394368"),
bigint("110427941548649020598956093796432407239217743554726184882600387580788736"),
bigint("220855883097298041197912187592864814478435487109452369765200775161577472"),
bigint("441711766194596082395824375185729628956870974218904739530401550323154944"),
bigint("883423532389192164791648750371459257913741948437809479060803100646309888"),
bigint("1766847064778384329583297500742918515827483896875618958121606201292619776"),
bigint("3533694129556768659166595001485837031654967793751237916243212402585239552"),
bigint("7067388259113537318333190002971674063309935587502475832486424805170479104"),
bigint("14134776518227074636666380005943348126619871175004951664972849610340958208"),
bigint("28269553036454149273332760011886696253239742350009903329945699220681916416"),
bigint("56539106072908298546665520023773392506479484700019806659891398441363832832"),
bigint("113078212145816597093331040047546785012958969400039613319782796882727665664"),
bigint("226156424291633194186662080095093570025917938800079226639565593765455331328"),
bigint("452312848583266388373324160190187140051835877600158453279131187530910662656"),
bigint("904625697166532776746648320380374280103671755200316906558262375061821325312"),
bigint("1809251394333065553493296640760748560207343510400633813116524750123642650624"),
bigint("3618502788666131106986593281521497120414687020801267626233049500247285301248"),
bigint("7237005577332262213973186563042994240829374041602535252466099000494570602496"),
bigint("14474011154664524427946373126085988481658748083205070504932198000989141204992"),
bigint("28948022309329048855892746252171976963317496166410141009864396001978282409984"),
bigint("57896044618658097711785492504343953926634992332820282019728792003956564819968"),
bigint("115792089237316195423570985008687907853269984665640564039457584007913129639936"),
}

powersTwo[0] = bigint("1")

local bigZero = bigint(0)
local bigOne = bigint(1)

function numberToBytes(num, bits, byteSize)
	if bits > #powersTwo then
		error("Too many bits. Must be <= " .. #powersTwo .. ".")
	end

	num = bigint(num)

	local resultBits = {}
	resultBits[1] = {}
	for i = bits - 1, 0, -1 do
		local expVal = powersTwo[i]
		local resultant = num - expVal
		if expVal <= resultant then
			-- Invalid data!
			return nil
		end

		if resultant < bigZero then
			-- A zero bit
			if #(resultBits[#resultBits]) >= byteSize then
				table.insert(resultBits, {0})
			else
				table.insert(resultBits[#resultBits], 0)
			end
		else
			-- A one bit
			num = resultant
			if #(resultBits[#resultBits]) >= byteSize then
				table.insert(resultBits, {1})
			else
				table.insert(resultBits[#resultBits], 1)
			end
		end

		if num == bigint(0) then
			break
		end
	end

	local results = {}
	for _, binarySeq in pairs(resultBits) do
		local thisResult = 0
		for k, bin in pairs(binarySeq) do
			if bin == 1 then
				thisResult = thisResult + 2^(byteSize - k)
			end
		end
		table.insert(results, thisResult)
	end

	return results
end

function bytesToNumber(bytes, bits, byteSize)
	if bits > #powersTwo then
		error("Too many bits. Must be <= " .. #powersTwo .. ".")
	end

	if #bytes > bits/byteSize then
		error("Too many bytes to store into the number of bits available. Must be <= " ..
			bits/byteSize .. ".")
	end

	local binary = {}
	for _, byte in pairs(bytes) do
		for i = byteSize - 1, 0, -1 do
			if byte - (2 ^ i) < 0 then
				table.insert(binary, 0)
			else
				table.insert(binary, 1)
				byte = byte - (2 ^ i)
			end
		end
	end

	local num = bigint(0)
	for i = 1, #binary do
		if binary[i] == 1 then
			num = num + powersTwo[bits - i]
		end
	end

	return tostring(num)
end

function encodeBigNumbers(numbers)
	for k, v in pairs(numbers) do
		numbers[k] = tostring(v)
	end
	return numbers
end

function stringToBytes(str)
	local result = {}
	for i = 1, #str do
		table.insert(result, string.byte(str, i))
	end
	return result
end

function bytesToString(bytes)
	local str = ""
	for _, v in pairs(bytes) do
		str = str .. string.char(v)
	end
	return str
end

function modexp(base, exponent, modulus)
	local r = 1

	while true do
		if exponent % 2 == bigOne then
			r = r * base % modulus
		end
		exponent = exponent / 2

		if exponent == bigZero then
			break
		end
		base = base * base % modulus
	end

	return r
end

function crypt(key, number)
	local exp
	if key.public then
		exp = bigint(key.public)
	else
		exp = bigint(key.private)
	end

	return tostring(modexp(bigint(number), exp, bigint(key.shared)))
end
