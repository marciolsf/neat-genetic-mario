config = require "config"
--require "genome"

function displayGenome(genome)
	forms.clear(netPicture,0x80808080)
	local network = genome.network
	local cells = {}
	local i = 1
	local cell = {}
	for dy=-config.BoxRadius,config.BoxRadius do
		for dx=-config.BoxRadius,config.BoxRadius do
			cell = {}
			cell.x = 50+5*dx
			cell.y = 70+5*dy
			cell.value = network.neurons[i].value
			cells[i] = cell
			i = i + 1
		end
	end
	local biasCell = {}
	biasCell.x = 80
	biasCell.y = 110
	biasCell.value = network.neurons[Inputs].value
	cells[Inputs] = biasCell
	
	for o = 1,Outputs do
		cell = {}
		cell.x = 220
		cell.y = 30 + 8 * o
		cell.value = network.neurons[config.NeatConfig.MaxNodes + o].value
		cells[config.NeatConfig.MaxNodes+o] = cell
		local color
		if cell.value > 0 then
			color = 0xFF0000FF --red
		else
			color = 0xFF000000 --white
		end
		--gui.drawText(223, 24+8*o, config.ButtonNames[o], color, 9)
		forms.drawText(netPicture,223, 24+8*o, config.ButtonNames[o], color, 9)
	end
	
	for n,neuron in pairs(network.neurons) do
		cell = {}
		if n > Inputs and n <= config.NeatConfig.MaxNodes then
			cell.x = 140
			cell.y = 40
			cell.value = neuron.value
			cells[n] = cell
		end
	end
	
	for n=1,4 do
		for _,gene in pairs(genome.genes) do
			if gene.enabled then
				local c1 = cells[gene.into]
				local c2 = cells[gene.out]
				if gene.into > Inputs and gene.into <= config.NeatConfig.MaxNodes then
					c1.x = 0.75*c1.x + 0.25*c2.x
					if c1.x >= c2.x then
						c1.x = c1.x - 40
					end
					if c1.x < 90 then
						c1.x = 90
					end
					
					if c1.x > 220 then
						c1.x = 220
					end
					c1.y = 0.75*c1.y + 0.25*c2.y
					
				end
				if gene.out > Inputs and gene.out <= config.NeatConfig.MaxNodes then
					c2.x = 0.25*c1.x + 0.75*c2.x
					if c1.x >= c2.x then
						c2.x = c2.x + 40
					end
					if c2.x < 90 then
						c2.x = 90
					end
					if c2.x > 220 then
						c2.x = 220
					end
					c2.y = 0.25*c1.y + 0.75*c2.y
				end
			end
		end
	end
	
	--gui.drawBox(50-config.BoxRadius*5-3,70-config.BoxRadius*5-3,50+config.BoxRadius*5+2,70+config.BoxRadius*5+2,0xFF000000, 0x80808080)
	forms.drawBox(netPicture, 50-config.BoxRadius*5-3,70-config.BoxRadius*5-3,50+config.BoxRadius*5+2,70+config.BoxRadius*5+2,0xFF000000, 0x80808080)
	--oid forms.drawBox(int componenthandle, int x, int y, int x2, int y2, [color? line = null], [color? background = null]) 
	for n,cell in pairs(cells) do
		if n > Inputs or cell.value ~= 0 then
			local color = math.floor((cell.value+1)/2*256)
			if color > 255 then color = 255 end
			if color < 0 then color = 0 end
			local opacity = 0xFF000000
			if cell.value == 0 then
				opacity = 0x50000000
			end
			color = opacity + color*0x10000 + color*0x100 + color
			forms.drawBox(netPicture,cell.x-2,cell.y-2,cell.x+2,cell.y+2,opacity,color)
			--gui.drawBox(cell.x-2,cell.y-2,cell.x+2,cell.y+2,opacity,color)
		end
	end
	for _,gene in pairs(genome.genes) do
		if gene.enabled then
			local c1 = cells[gene.into]
			local c2 = cells[gene.out]
			local opacity = 0xA0000000
			if c1.value == 0 then
				opacity = 0x20000000
			end
			
			local color = 0x80-math.floor(math.abs(mathFunctions.sigmoid(gene.weight))*0x80)
			if gene.weight > 0 then 
				color = opacity + 0x8000 + 0x10000*color
			else
				color = opacity + 0x800000 + 0x100*color
			end
			--gui.drawLine(c1.x+1, c1.y, c2.x-3, c2.y, color)
			forms.drawLine(netPicture,c1.x+1, c1.y, c2.x-3, c2.y, color)
		end
	end
	
	--gui.drawBox(49,71,51,78,0x00000000,0x80FF0000)
	forms.drawBox(netPicture, 49,71,51,78,0x00000000,0x80FF0000)
	--if forms.ischecked(showMutationRates) then
		local pos = 150
		for mutation,rate in pairs(genome.mutationRates) do			
			--gui.drawText(100, pos, mutation .. ": " .. rate, 0xFF000000, 10)
				forms.drawText(netPicture, 20, pos, mutation .. ": " .. rate , 0xFF000000, 10)
			--forms.drawText(pictureBox,400,pos, mutation .. ": " .. rate)
			
			--void forms.drawText(int componenthandle, int x, int y, string message, [color? forecolor = null], [color? backcolor = null], [int? fontsize = null], [string fontfamily = null], [string fontstyle = null], [string horizalign = null], [string vertalign = null]) 

			pos = pos + 8
		end
	--end
	forms.refresh(netPicture)
end


function writeFile(filename)
	local file = io.open(filename, "w")
	file:write(pool.generation .. "\n")
	file:write(pool.maxFitness .. "\n")
	file:write(#pool.species .. "\n")
	for n,species in pairs(pool.species) do
			file:write(species.topFitness .. "\n")
			file:write(species.staleness .. "\n")
			file:write(#species.genomes .. "\n")
			for m,genome in pairs(species.genomes) do
					file:write(genome.fitness .. "\n")
					file:write(genome.maxneuron .. "\n")
					for mutation,rate in pairs(genome.mutationRates) do
							file:write(mutation .. "\n")
							file:write(rate .. "\n")
					end
					file:write("done\n")
					
					file:write(#genome.genes .. "\n")
					for l,gene in pairs(genome.genes) do
							file:write(gene.into .. " ")
							file:write(gene.out .. " ")
							file:write(gene.weight .. " ")
							file:write(gene.innovation .. " ")
							if(gene.enabled) then
									file:write("1\n")
							else
									file:write("0\n")
							end
					end
			end
	end
	file:close()
end

function savePool()
local filename = forms.gettext(saveLoadFile)
console.writeline("Saving pool data to: " .. filename)
writeFile(filename,"savePool()")
end


function loadFile(filename)
	local filename = forms.gettext(saveLoadFile)
	console.writeline("Loading pool from " .. filename)
	local file = io.open(filename, "r")
	pool = newPool()
	pool.generation = file:read("*number")
		console.writeline("pool.generation: " .. pool.generation)
	pool.maxFitness = file:read("*number")
		console.writeline("pool.maxFitness: " .. pool.maxFitness)
	forms.settext(MaxLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
	local numSpecies = file:read("*number")
	for s=1,numSpecies do
			local species = newSpecies()
			table.insert(pool.species, species)
			species.topFitness = file:read("*number")
				console.writeline("species.topFitness: " .. species.topFitness)
			species.staleness = file:read("*number")
				console.writeline("species.staleness: " .. species.staleness)
			local numGenomes = file:read("*number")
			--if numGenomes == nil then --fixed bug where the file fails to load and loads Nil into variable
			--	numGenomes = 1
			--end
			for g=1,numGenomes do
					local genome = newGenome()
					table.insert(species.genomes, genome)
					genome.fitness = file:read("*number")
						console.writeline("genome.fitness: " .. genome.fitness)
					genome.maxneuron = file:read("*number")
						console.writeline("genome.maxneuron: " .. genome.maxneuron)
					local line = file:read("*line")
					while line ~= "done" do							
							genome.mutationRates[line] = file:read("*number")
							line = file:read("*line")
					end
						console.writeline("Read all mutations")
					local numGenes = file:read("*number")
					for n=1,numGenes do

							local gene = newGene()
							local enabled
							
							local geneStr = file:read("*line")
							local geneArr = mysplit(geneStr)
							gene.into = tonumber(geneArr[1])
							gene.out = tonumber(geneArr[2])
							gene.weight = tonumber(geneArr[3])
							gene.innovation = tonumber(geneArr[4])
							enabled = tonumber(geneArr[5])


							if enabled == 0 then
									gene.enabled = false
							else
									gene.enabled = true
							end
							
							table.insert(genome.genes, gene)
					end
					console.writeline("Read all genes")
			end
	end
	console.writeline("closing the file...")

	file:close()
	console.writeline("Pool loaded.")

	while fitnessAlreadyMeasured() do
			nextGenome()
	end

	initializeRun()
	pool.currentFrame = pool.currentFrame + 1
end


function loadPool()
	filename = forms.openfile("DP1.state.pool",config.PoolDir) 
	forms.settext(saveLoadFile, filename)
	loadFile(filename)
end

function playTop()
	local maxfitness = 0
	local maxs, maxg
	for s,species in pairs(pool.species) do
		for g,genome in pairs(species.genomes) do
			if genome.fitness > maxfitness then
				maxfitness = genome.fitness
				maxs = s
				maxg = g
			end
		end
	end
	
	pool.currentSpecies = maxs
	pool.currentGenome = maxg
	pool.maxFitness = maxfitness
	forms.settext(MaxLabel, "Max Fitness: " .. math.floor(pool.maxFitness))
	initializeRun()
	pool.currentFrame = pool.currentFrame + 1
	return
end

function initializeRun()
	savestate.load(config.NeatConfig.StateFileName);
	if config.StartPowerup ~= NIL then
		game.writePowerup(config.StartPowerup)
	end
	rightmost = 0
	topMost = 400
	pool.currentFrame = 0
	timeout = config.NeatConfig.TimeoutConstant
	game.clearJoypad()
	startCoins = game.getCoins()
	startScore = game.getScore()
	startLives = game.getLives()
	checkMarioCollision = true
	marioHitCounter = 0
	powerUpCounter = 0
	died = 0
	powerUpBefore = game.getPowerup()
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	generateNetwork(genome)
	evaluateCurrent()
end

function mysplit(inputstr, sep)
	if sep == nil then
			sep = "%s"
	end
	local t={} ; i=1
	for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
			t[i] = str
			i = i + 1
	end
	return t
end

function flipState()
	if config.Running == true then
		config.Running = false
		forms.settext(startButton, "Start")
	else
		config.Running = true
		forms.settext(startButton, "Stop")
	end
end

function drawForm(form)
	GenerationLabel = forms.label(form, "Generation: " .. pool.generation, 5, 5)
	SpeciesLabel = forms.label(form, "Species: " .. pool.currentSpecies, 130, 5)
	GenomeLabel = forms.label(form, "Genome: " .. pool.currentGenome, 230, 5)
	MeasuredLabel = forms.label(form, "Measured: " .. "", 375, 5)
	
	FitnessLabel = forms.label(form, "Fitness: " .. "", 5, 30)
	MaxLabel = forms.label(form, "Max: " .. "", 130, 30)
	averageFitnessLabel = forms.label(form, "Avg Fitness: " .. "", 230, 30, 90, 14)
	roomIDLabel = forms.label(form,"Room ID: " .. "", 375, 30,110,14 )
	
	CoinsLabel = forms.label(form, "Coins: " .. "", 5, 65, 90, 14)
	ScoreLabel = forms.label(form, "Score: " .. "", 130, 65, 90, 14)
	DmgLabel = forms.label(form, "Damage: " .. "", 230, 65, 110, 14)
	timeoutLabel = forms.label(form, "Timeout: " .. "", 375, 65, 300, 14)
	
	RightMostLabel = forms.label(form, "Rightmost: " .. "", 5, 80)
	LivesLabel = forms.label(form, "Lives: " .. "", 130, 80, 90, 14)
	PowerUpLabel = forms.label(form, "PowerUp: " .. "", 230, 80, 110, 14)
	OWSwitchLabel = forms.label(form, "OWSwitch: " .. "", 375, 80, 110, 14)
	
	
	
	saveButton = forms.button(form, "Save", savePool, 5, 102)
	loadButton = forms.button(form, "Load", loadPool, 80, 102)
	startButton = forms.button(form, "Start", flipState, 155, 102)
	restartButton = forms.button(form, "Restart", initializePool, 230, 102)
	playTopButton = forms.button(form, "Play Top", playTop, 300, 102)
	showNetwork = forms.checkbox(form, "Show Map", 400, 102)

	
	saveLoadFile = forms.textbox(form, config.NeatConfig.Filename .. ".pool", 575, 25, nil, 5, 148)
	saveLoadLabel = forms.label(form, "Save/Load:", 7, 129)
end