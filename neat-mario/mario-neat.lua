--Update to Seth-Bling's MarI/O app

config = require "config"
spritelist = require "spritelist"
game = require "game"
mathFunctions = require "mathFunctions"
board = require "board"
--genome = require "genome"

Inputs = config.InputSize+1
Outputs = #config.ButtonNames



function newInnovation()
	pool.innovation = pool.innovation + 1
	return pool.innovation
end

function newPool()
	local pool = {}
	pool.species = {}
	pool.generation = 0
	pool.innovation = Outputs
	pool.currentSpecies = 1
	pool.currentGenome = 1
	pool.currentFrame = 0
	pool.maxFitness = 0
	pool.coinBonus = 0
	pool.averageFitness = 0
	
	return pool
end

function newSpecies()
	local species = {}
	species.topFitness = 0
	species.staleness = 0
	species.genomes = {}
	species.averageFitness = 0
	
	return species
end

function newGenome()
	local genome = {}
	genome.genes = {}
	genome.fitness = 0
	genome.adjustedFitness = 0
	genome.network = {}
	genome.maxneuron = 0
	genome.globalRank = 0
	genome.mutationRates = {}
	genome.mutationRates["connections"] = config.NeatConfig.MutateConnectionsChance
	genome.mutationRates["link"] = config.NeatConfig.LinkMutationChance
	genome.mutationRates["bias"] = config.NeatConfig.BiasMutationChance
	genome.mutationRates["node"] = config.NeatConfig.NodeMutationChance
	genome.mutationRates["enable"] = config.NeatConfig.EnableMutationChance
	genome.mutationRates["disable"] = config.NeatConfig.DisableMutationChance
	genome.mutationRates["step"] = config.NeatConfig.StepSize
	
	return genome
end

function copyGenome(genome)
	local genome2 = newGenome()
	for g=1,#genome.genes do
		table.insert(genome2.genes, copyGene(genome.genes[g]))
	end
	genome2.maxneuron = genome.maxneuron
	genome2.mutationRates["connections"] = genome.mutationRates["connections"]
	genome2.mutationRates["link"] = genome.mutationRates["link"]
	genome2.mutationRates["bias"] = genome.mutationRates["bias"]
	genome2.mutationRates["node"] = genome.mutationRates["node"]
	genome2.mutationRates["enable"] = genome.mutationRates["enable"]
	genome2.mutationRates["disable"] = genome.mutationRates["disable"]
	
	return genome2
end

function basicGenome()
	local genome = newGenome()
	local innovation = 1

	genome.maxneuron = Inputs
	mutate(genome)
	
	return genome
end

function newGene()
	local gene = {}
	gene.into = 0
	gene.out = 0
	gene.weight = 0.0
	gene.enabled = true
	gene.innovation = 0
	
	return gene
end

function copyGene(gene)
	local gene2 = newGene()
	gene2.into = gene.into
	gene2.out = gene.out
	gene2.weight = gene.weight
	gene2.enabled = gene.enabled
	gene2.innovation = gene.innovation
	
	return gene2
end

function newNeuron()
	local neuron = {}
	neuron.incoming = {}
	neuron.value = 0.0
	--neuron.dw = 1
	return neuron
end

function generateNetwork(genome)
	local network = {}
	network.neurons = {}
	
	for i=1,Inputs do
		network.neurons[i] = newNeuron()
	end
	
	for o=1,Outputs do
		network.neurons[config.NeatConfig.MaxNodes+o] = newNeuron()
	end
	
	table.sort(genome.genes, function (a,b)
		return (a.out < b.out)
	end)
	for i=1,#genome.genes do
		local gene = genome.genes[i]
		if gene.enabled then
			if network.neurons[gene.out] == nil then
				network.neurons[gene.out] = newNeuron()
			end
			local neuron = network.neurons[gene.out]
			table.insert(neuron.incoming, gene)
			if network.neurons[gene.into] == nil then
				network.neurons[gene.into] = newNeuron()
			end
		end
	end
	
	genome.network = network
end

function evaluateNetwork(network, inputs, inputDeltas)
	table.insert(inputs, 1)
	table.insert(inputDeltas,99)
	if #inputs ~= Inputs then
		console.writeline("Incorrect number of neural network inputs.")
		return {}
	end
	

	for i=1,Inputs do
		network.neurons[i].value = inputs[i] * inputDeltas[i]
		--network.neurons[i].value = inputs[i]
	end
	
	for _,neuron in pairs(network.neurons) do
		local sum = 0
		for j = 1,#neuron.incoming do
			local incoming = neuron.incoming[j]
			local other = network.neurons[incoming.into]
			sum = sum + incoming.weight * other.value
		end
		
		if #neuron.incoming > 0 then
			neuron.value = mathFunctions.sigmoid(sum)
		end
	end
	
	local outputs = {}
	for o=1,Outputs do
		local button = "P1 " .. config.ButtonNames[o]
		if network.neurons[config.NeatConfig.MaxNodes+o].value > 0 then
			outputs[button] = true
		else
			outputs[button] = false
		end
	end
	
	return outputs
end

function crossover(g1, g2)
	-- Make sure g1 is the higher fitness genome
	if g2.fitness > g1.fitness then
		tempg = g1
		g1 = g2
		g2 = tempg
	end

	local child = newGenome()
	
	local innovations2 = {}
	for i=1,#g2.genes do
		local gene = g2.genes[i]
		innovations2[gene.innovation] = gene
	end
	
	for i=1,#g1.genes do
		local gene1 = g1.genes[i]
		local gene2 = innovations2[gene1.innovation]
		if gene2 ~= nil and math.random(2) == 1 and gene2.enabled then
			table.insert(child.genes, copyGene(gene2))
		else
			table.insert(child.genes, copyGene(gene1))
		end
	end
	
	child.maxneuron = math.max(g1.maxneuron,g2.maxneuron)
	
	for mutation,rate in pairs(g1.mutationRates) do
		child.mutationRates[mutation] = rate
	end
	
	return child
end

function randomNeuron(genes, nonInput)
	local neurons = {}
	if not nonInput then
		for i=1,Inputs do
			neurons[i] = true
		end
	end
	for o=1,Outputs do
		neurons[config.NeatConfig.MaxNodes+o] = true
	end
	for i=1,#genes do
		if (not nonInput) or genes[i].into > Inputs then
			neurons[genes[i].into] = true
		end
		if (not nonInput) or genes[i].out > Inputs then
			neurons[genes[i].out] = true
		end
	end

	local count = 0
	for _,_ in pairs(neurons) do
		count = count + 1
	end
	local n = math.random(1, count)
	
	for k,v in pairs(neurons) do
		n = n-1
		if n == 0 then
			return k
		end
	end
	
	return 0
end

function containsLink(genes, link)
	for i=1,#genes do
		local gene = genes[i]
		if gene.into == link.into and gene.out == link.out then
			return true
		end
	end
end

function pointMutate(genome)
	local step = genome.mutationRates["step"]
	
	for i=1,#genome.genes do
		local gene = genome.genes[i]
		if math.random() < config.NeatConfig.PerturbChance then
			gene.weight = gene.weight + math.random() * step*2 - step
		else
			gene.weight = math.random()*4-2
		end
	end
end

function linkMutate(genome, forceBias)
	local neuron1 = randomNeuron(genome.genes, false)
	local neuron2 = randomNeuron(genome.genes, true)
	 
	local newLink = newGene()
	if neuron1 <= Inputs and neuron2 <= Inputs then
		--Both input nodes
		return
	end
	if neuron2 <= Inputs then
		-- Swap output and input
		local temp = neuron1
		neuron1 = neuron2
		neuron2 = temp
	end

	newLink.into = neuron1
	newLink.out = neuron2
	if forceBias then
		newLink.into = Inputs
	end
	
	if containsLink(genome.genes, newLink) then
		return
	end
	newLink.innovation = newInnovation()
	newLink.weight = math.random()*4-2
	
	table.insert(genome.genes, newLink)
end

function nodeMutate(genome)
	if #genome.genes == 0 then
		return
	end

	genome.maxneuron = genome.maxneuron + 1

	local gene = genome.genes[math.random(1,#genome.genes)]
	if not gene.enabled then
		return
	end
	gene.enabled = false
	
	local gene1 = copyGene(gene)
	gene1.out = genome.maxneuron
	gene1.weight = 1.0
	gene1.innovation = newInnovation()
	gene1.enabled = true
	table.insert(genome.genes, gene1)
	
	local gene2 = copyGene(gene)
	gene2.into = genome.maxneuron
	gene2.innovation = newInnovation()
	gene2.enabled = true
	table.insert(genome.genes, gene2)
end

function enableDisableMutate(genome, enable)
	local candidates = {}
	for _,gene in pairs(genome.genes) do
		if gene.enabled == not enable then
			table.insert(candidates, gene)
		end
	end
	
	if #candidates == 0 then
		return
	end
	
	local gene = candidates[math.random(1,#candidates)]
	gene.enabled = not gene.enabled
end

function mutate(genome)
	for mutation,rate in pairs(genome.mutationRates) do
		if math.random(1,2) == 1 then
			genome.mutationRates[mutation] = 0.95*rate
		else
			genome.mutationRates[mutation] = 1.05263*rate
		end
	end

	if math.random() < genome.mutationRates["connections"] then
		pointMutate(genome)
	end
	
	local p = genome.mutationRates["link"]
	while p > 0 do
		if math.random() < p then
			linkMutate(genome, false)
		end
		p = p - 1
	end

	p = genome.mutationRates["bias"]
	while p > 0 do
		if math.random() < p then
			linkMutate(genome, true)
		end
		p = p - 1
	end
	
	p = genome.mutationRates["node"]
	while p > 0 do
		if math.random() < p then
			nodeMutate(genome)
		end
		p = p - 1
	end
	
	p = genome.mutationRates["enable"]
	while p > 0 do
		if math.random() < p then
			enableDisableMutate(genome, true)
		end
		p = p - 1
	end

	p = genome.mutationRates["disable"]
	while p > 0 do
		if math.random() < p then
			enableDisableMutate(genome, false)
		end
		p = p - 1
	end
end

function disjoint(genes1, genes2)
	local i1 = {}
	for i = 1,#genes1 do
		local gene = genes1[i]
		i1[gene.innovation] = true
	end

	local i2 = {}
	for i = 1,#genes2 do
		local gene = genes2[i]
		i2[gene.innovation] = true
	end
	
	local disjointGenes = 0
	for i = 1,#genes1 do
		local gene = genes1[i]
		if not i2[gene.innovation] then
			disjointGenes = disjointGenes+1
		end
	end
	
	for i = 1,#genes2 do
		local gene = genes2[i]
		if not i1[gene.innovation] then
			disjointGenes = disjointGenes+1
		end
	end
	
	local n = math.max(#genes1, #genes2)
	
	return disjointGenes / n
end

function weights(genes1, genes2)
	local i2 = {}
	for i = 1,#genes2 do
		local gene = genes2[i]
		i2[gene.innovation] = gene
	end

	local sum = 0
	local coincident = 0
	for i = 1,#genes1 do
		local gene = genes1[i]
		if i2[gene.innovation] ~= nil then
			local gene2 = i2[gene.innovation]
			sum = sum + math.abs(gene.weight - gene2.weight)
			coincident = coincident + 1
		end
	end
	
	return sum / coincident
end
	
function sameSpecies(genome1, genome2)
	local dd = config.NeatConfig.DeltaDisjoint*disjoint(genome1.genes, genome2.genes)
	local dw = config.NeatConfig.DeltaWeights*weights(genome1.genes, genome2.genes) 
	return dd + dw < config.NeatConfig.DeltaThreshold
end

function rankGlobally()
	local global = {}
	for s = 1,#pool.species do
		local species = pool.species[s]
		for g = 1,#species.genomes do
			table.insert(global, species.genomes[g])
		end
	end
	table.sort(global, function (a,b)
		return (a.fitness < b.fitness)
	end)
	
	for g=1,#global do
		global[g].globalRank = g
	end
end

function calculateAverageFitness(species)
	local total = 0
	
	for g=1,#species.genomes do
		local genome = species.genomes[g]
		total = total + genome.globalRank
	end
	
	species.averageFitness = total / #species.genomes
end

function totalAverageFitness()
	local total = 0
	for s = 1,#pool.species do
		local species = pool.species[s]
		total = total + species.averageFitness
	end

	return total
end

function cullSpecies(cutToOne)
	for s = 1,#pool.species do
		local species = pool.species[s]
		
		table.sort(species.genomes, function (a,b)
			return (a.fitness > b.fitness)
		end)
		
		local remaining = math.ceil(#species.genomes/2)
		if cutToOne then
			remaining = 1
		end
		while #species.genomes > remaining do
			table.remove(species.genomes)
		end
	end
end

function breedChild(species)
	local child = {}
	if math.random() < config.NeatConfig.CrossoverChance then
		g1 = species.genomes[math.random(1, #species.genomes)]
		g2 = species.genomes[math.random(1, #species.genomes)]
		child = crossover(g1, g2)
	else
		g = species.genomes[math.random(1, #species.genomes)]
		child = copyGenome(g)
	end
	
	mutate(child)
	
	return child
end

function removeStaleSpecies()
	local survived = {}

	for s = 1,#pool.species do
		local species = pool.species[s]
		
		table.sort(species.genomes, function (a,b)
			return (a.fitness > b.fitness)
		end)
		
		if species.genomes[1].fitness > species.topFitness then
			species.topFitness = species.genomes[1].fitness
			species.staleness = 0
		else
			species.staleness = species.staleness + 1
		end
		if species.staleness < config.NeatConfig.StaleSpecies or species.topFitness >= pool.maxFitness then
			table.insert(survived, species)
		end
	end

	pool.species = survived
end

function removeWeakSpecies()
	local survived = {}

	local sum = totalAverageFitness()
	for s = 1,#pool.species do
		local species = pool.species[s]
		breed = math.floor(species.averageFitness / sum * config.NeatConfig.Population)
		if breed >= 1 then
			table.insert(survived, species)
		end
	end

	pool.species = survived
end


function addToSpecies(child)
	local foundSpecies = false
	for s=1,#pool.species do
		local species = pool.species[s]
		if not foundSpecies and sameSpecies(child, species.genomes[1]) then
			table.insert(species.genomes, child)
			foundSpecies = true
		end
	end
	
	if not foundSpecies then
		local childSpecies = newSpecies()
		table.insert(childSpecies.genomes, child)
		table.insert(pool.species, childSpecies)
	end
end

function newGeneration()
	cullSpecies(false) -- Cull the bottom half of each species
	rankGlobally()
	removeStaleSpecies()
	rankGlobally()
	for s = 1,#pool.species do
		local species = pool.species[s]
		calculateAverageFitness(species)
	end
	removeWeakSpecies()
	local sum = totalAverageFitness()
	local children = {}
	for s = 1,#pool.species do
		local species = pool.species[s]
		breed = math.floor(species.averageFitness / sum * config.NeatConfig.Population) - 1
		for i=1,breed do
			table.insert(children, breedChild(species))
		end
	end
	cullSpecies(true) -- Cull all but the top member of each species
	while #children + #pool.species < config.NeatConfig.Population do
		local species = pool.species[math.random(1, #pool.species)]
		table.insert(children, breedChild(species))
	end
	for c=1,#children do
		local child = children[c]
		addToSpecies(child)
	end
	
	pool.generation = pool.generation + 1
	
	--writeFile("backup." .. pool.generation .. "." .. forms.gettext(saveLoadFile))
	writeFile(forms.gettext(saveLoadFile) .. ".gen" .. pool.generation .. ".pool")
end
	
function initializePool()
	pool = newPool()

	for i=1,config.NeatConfig.Population do
		basic = basicGenome()
		addToSpecies(basic)
	end

	initializeRun()
end


function evaluateCurrent()
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	
	local inputDeltas = {}
	inputs, inputDeltas = game.getInputs()
	
	controller = evaluateNetwork(genome.network, inputs, inputDeltas)
	
	if controller["P1 Left"] and controller["P1 Right"] then
		controller["P1 Left"] = false
		controller["P1 Right"] = false
	end
	if controller["P1 Up"] and controller["P1 Down"] then
		controller["P1 Up"] = false
		controller["P1 Down"] = false
	end

	joypad.set(controller)
end

if pool == nil then
	initializePool()
end


function nextGenome()
	pool.currentGenome = pool.currentGenome + 1
	if pool.currentGenome > #pool.species[pool.currentSpecies].genomes then
		pool.currentGenome = 1
		pool.currentSpecies = pool.currentSpecies+1
		if pool.currentSpecies > #pool.species then
			newGeneration()
			pool.currentSpecies = 1
		end
	end
end

function fitnessAlreadyMeasured()
	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	
	return genome.fitness ~= 0
end



form = forms.newform(600, 600, "Mario-Neat")
netPicture = forms.pictureBox(form, 5, 175, 530, 350)




function onExit()
	forms.destroy(form)
end

writeFile(config.PoolDir.."temp.pool")

event.onexit(onExit)

--[[Initialize form]]

GenerationLabel = forms.label(form, "Generation: " .. pool.generation, 5, 5)
SpeciesLabel = forms.label(form, "Species: " .. pool.currentSpecies, 130, 5)
GenomeLabel = forms.label(form, "Genome: " .. pool.currentGenome, 230, 5)
MeasuredLabel = forms.label(form, "Measured: " .. "", 330, 5)

FitnessLabel = forms.label(form, "Fitness: " .. "", 5, 30)
MaxLabel = forms.label(form, "Max: " .. "", 130, 30)
--averageFitnessLabel = forms.label(form, "Average Fitness: " .. "", 230, 30)

CoinsLabel = forms.label(form, "Coins: " .. "", 5, 65)
ScoreLabel = forms.label(form, "Score: " .. "", 130, 65, 90, 14)
LivesLabel = forms.label(form, "Lives: " .. "", 130, 80, 90, 14)
DmgLabel = forms.label(form, "Damage: " .. "", 230, 65, 110, 14)
PowerUpLabel = forms.label(form, "PowerUp: " .. "", 230, 80, 110, 14)

startButton = forms.button(form, "Start", flipState, 155, 102)

restartButton = forms.button(form, "Restart", initializePool, 155, 102)
saveButton = forms.button(form, "Save", savePool, 5, 102)
loadButton = forms.button(form, "Load", loadPool, 80, 102)
playTopButton = forms.button(form, "Play Top", playTop, 230, 102)

saveLoadFile = forms.textbox(form, config.NeatConfig.Filename .. ".pool", 530, 25, nil, 5, 148)
saveLoadLabel = forms.label(form, "Save/Load:", 7, 129)
spritelist.InitSpriteList()
spritelist.InitExtSpriteList()

--[[Main game loop
Everything in this loop runs on every fram
]]

--console.writeline("Gen " .. pool.generation .. " species " .. pool.currentSpecies  .. " genome " .. pool.currentGenome .. " current fitness: " .. fitness .. " max fitness: " .. pool.maxFitness .. " Coin Bonus: " .. pool.coinBonus .. " Frame Count: " .. pool.currentFrame)
console.writeline("Gen, species, genome, current fitness, max fitness, Average Gen Fitness, Coin Bonus, Frame Count, Beat Game")
while true do
	
	if config.Running == true then

	local species = pool.species[pool.currentSpecies]
	local genome = species.genomes[pool.currentGenome]
	
	displayGenome(genome)
	
	if pool.currentFrame%5 == 0 then
		evaluateCurrent()
	end

	joypad.set(controller)

	game.getPositions()
	if marioX > rightmost then
		rightmost = marioX
		timeout = config.NeatConfig.TimeoutConstant
	end
	
	local hitTimer = game.getMarioHitTimer()
	
	if checkMarioCollision == true then
		if hitTimer > 0 then
			marioHitCounter = marioHitCounter + 1
			--console.writeline("Mario took damage, hit counter: " .. marioHitCounter)
			checkMarioCollision = false
		end
	end
	
	if hitTimer == 0 then
		checkMarioCollision = true
	end
	
	powerUp = game.getPowerup()
	if powerUp > 0 then
		if powerUp ~= powerUpBefore then
			powerUpCounter = powerUpCounter+1
			powerUpBefore = powerUp
		end
	end
	
	Lives = game.getLives()

	timeout = timeout - 1
	
	local timeoutBonus = pool.currentFrame / 4
	if timeout + timeoutBonus <= 0 then
	
		local coins = game.getCoins() - startCoins
		local score = game.getScore() - startScore
		
		--console.writeline("Coins: " .. coins .. " score: " .. score)

		--local coinScoreFitness = (coins * 50) + (score * 0.2)
		coinWeight = config.NeatConfig.coinWeight
		--coinWeight = 50
		local coinScoreFitness = (coins * coinWeight) + (score * 0.2)
		if (coins + score) > 0 then
			pool.coinBonus = coins + score 
			--console.writeline("Coins and Score added " .. coinScoreFitness .. " fitness")
		end
		
		local hitPenalty = marioHitCounter * 100
		local powerUpBonus = powerUpCounter * 100
	
		local fitness = coinScoreFitness - hitPenalty + powerUpBonus + rightmost - pool.currentFrame / 2

		if startLives < Lives then
			local ExtraLiveBonus = (Lives - startLives)*1000
			fitness = fitness + ExtraLiveBonus
			console.writeline("ExtraLiveBonus added " .. ExtraLiveBonus)
		end

		beatGame = 0

		if rightmost > 4816 then
			beatGame = 1
			fitness = fitness + 1000
			--console.writeline("!!!!!!Beat level!!!!!!!")
		end
		if fitness == 0 then
			fitness = -1
		end
		genome.fitness = fitness
		
		if fitness > pool.maxFitness then
			--console.writeline("MarI/O's fitness evolved from " .. pool.maxFitness .. " to " .. fitness)
			pool.maxFitness = fitness
			--writeFile("backup." .. pool.generation .. "." .. forms.gettext(saveLoadFile))
			writeFile(forms.gettext(saveLoadFile) .. ".gen" .. pool.generation .. ".pool")
			
		end



		local avgSum = 0
		avgSum = totalAverageFitness()
		pool.averageFitness = avgSum
		--console.writeline("Pool average fitness = " .. avgSum)


		--Also added a few more bits of information for better context
		console.writeline(pool.generation .. ", " .. pool.currentSpecies  .. ", " .. pool.currentGenome .. ", " .. fitness .. ", " .. pool.maxFitness .. ", " .. pool.averageFitness .. ", " .. pool.coinBonus .. ", " .. pool.currentFrame .. ", " .. beatGame)
		--gui.drawText(100,100,"Gen " .. pool.generation .. " genome " .. pool.currentGenome  .. " species " .. pool.currentSpecies .. " current fitness: " .. fitness .. " max fitness: " .. pool.maxFitness .. " Coin Bonus: " .. pool.coinBonus .. " Frame Count: " .. pool.currentFrame)

		
		pool.currentSpecies = 1
		pool.currentGenome = 1
		while fitnessAlreadyMeasured() do
			nextGenome()
		end
		initializeRun()
	end

	local measured = 0
	local total = 0
	for _,species in pairs(pool.species) do
		for _,genome in pairs(species.genomes) do
			total = total + 1
			if genome.fitness ~= 0 then
				measured = measured + 1
			end
		end
	end
	



	gui.drawEllipse(game.screenX-84, game.screenY-84, 192, 192, 0x50000000) 
	forms.settext(FitnessLabel, "Fitness: " .. math.floor(rightmost - (pool.currentFrame) / 2 - (timeout + timeoutBonus)*2/3))
	forms.settext(GenerationLabel, "Generation: " .. pool.generation)
	forms.settext(SpeciesLabel, "Species: " .. pool.currentSpecies)
	forms.settext(GenomeLabel, "Genome: " .. pool.currentGenome)
	forms.settext(MaxLabel, "Max: " .. math.floor(pool.maxFitness))
	--forms.settext(averageFitnessLabel, "Average Fitness: " .. math.floor(avgSum))
	forms.settext(MeasuredLabel, "Measured: " .. math.floor(measured/total*100) .. "%")
	forms.settext(CoinsLabel, "Coins: " .. (game.getCoins() - startCoins))
	forms.settext(ScoreLabel, "Score: " .. (game.getScore() - startScore))
	forms.settext(LivesLabel, "Lives: " .. Lives)
	forms.settext(DmgLabel, "Damage: " .. marioHitCounter)
	forms.settext(PowerUpLabel, "PowerUp: " .. powerUpCounter)
	

	pool.currentFrame = pool.currentFrame + 1
	
	end
	emu.frameadvance();
	
end