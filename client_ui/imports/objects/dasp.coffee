#Import web3
Web3 = require 'web3'
web3 = window.web3
if typeof web3 != undefined
  web3 = new Web3(web3.currentProvider)
else
  web3 = new Web3(new Web3.providers.HttpProvider("http://localhost:9545"))

web3.eth.getAccounts().then(
  (accounts) ->
    web3.eth.defaultAccount = accounts[0]
)

#Import node modules
ipfsAPI = require 'ipfs-api'
ipfs = ipfsAPI('ipfs.infura.io', '5001', {protocol: 'https'})
git = require 'gift'
fs = require 'fs'
bl = require 'bl'
keccak256 = require('js-sha3').keccak256

#Helper functions
hexToStr = (hex) ->
  hex = hex.substr(2)
  str = ''
  for i in [0..hex.length - 1] by 2
    str += String.fromCharCode(parseInt(hex.substr(i, 2), 16))
  return str

export DASP = () ->
  self = this
  self.metadata = null

  self.addrs =
    main: null
    dao: null
    member: null
    vault: null
    tasks: null
    git: null

  self.contracts =
    main: null
    dao: null
    member: null
    vault: null
    tasks: null
    git: null

  self.repoIPFSHash = null
  self.memberList = [];

  self.initWithAddr = (addr, options, callback) ->
    self.addrs.main = addr
    mainAbi = (options && options.mainAbi) || require "../abi/mainABI.json"
    self.contracts.main = new web3.eth.Contract(mainAbi, self.addrs.main)
    console.log(self.contracts.main)
    moduleNames = (options && options.moduleNames) || ['DAO', 'MEMBER', 'VAULT', 'TASKS', 'GIT']
    #Todo: read module names from main contract
    initMod = (mod) ->
      #Get module address
      return self.contracts.main.methods.moduleAddresses('0x' + keccak256(mod)).call().then(
        (result) ->
          console.log(result)
          lowerMod = mod.toLowerCase()
          self.addrs[lowerMod] = result
          #Get module ABI's IPFS hash
          return self.contracts.main.methods.getABIHashForMod('0x' + keccak256(mod)).call().then(
            (abiHash) ->
              return new Promise((fullfill, reject) ->
                #Get module ABI
                ipfs.files.cat(hexToStr(abiHash),
                  (error, stream) ->
                    if error != null
                      if callback != null
                        callback(error)
                      reject(error)
                      throw error
                    stream.pipe(bl((error, data) ->
                      if error != null
                        if callback != null
                          callback(error)
                        reject(error)
                        throw error
                      abi = JSON.parse(data.toString()).abi
                      #Initialize module contract
                      self.contracts[lowerMod] = new web3.eth.Contract(abi, self.addrs[lowerMod])

                      fullfill()
                      return
                    ))
                    return
                )
              )
          )
      )
    initAllMods = (initMod(mod) for mod in moduleNames)
    Promise.all(initAllMods).then(
      ()->
        self.contracts.git.methods.getCurrentIPFSHash().call(
          (error, result) ->
            if error != null
              if callback != null
                callback(error)
            else
              self.repoIPFSHash = hexToStr result
              if callback != null
                callback(null)

            return
        )
    )
    return

  self.lsRepo = (path, callback) ->
    fullPath = "#{self.repoIPFSHash}#{path}"
    ipfs.files.cat(fullPath, (err, stream) ->
      if err != null
        ipfs.ls(fullPath, (error, result) ->
          if error != null
            if callback != null
              callback(error, 'dir', null)
          else
            if callback != null
              callback(null, 'dir', result.Objects[0].Links)
        )
      else
        stream.pipe(bl((error, data) ->
          if callback != null
            callback(null, 'file', data)
        ))
    )

    return

  self.downloadFile = (path, callback) ->
    fullPath = "#{self.repoIPFSHash}#{path}"
    ipfs.files.cat(fullPath, (err, stream) ->
      if err != null
        if callback != null
          callback(err)
        throw err
      if callback != null
        fileName = path.slice(path.lastIndexOf('/'))
        file = fs.createWriteStream(fileName)
        stream.pipe(file)
        callback(null)
    )
    return

  self.lsMembers = (callback) ->
    self.memberList = []
    return self.contracts.member.methods.memberCount().call().then(
      (memberCount) ->
        getMember = (id) ->
          return self.contracts.member.methods.memberList(id).call().then(
            (member) ->
              return new Promise((fullfill, reject) ->
                self.memberList.push(member)
                if member.userAddress != '0x'
                  fullfill()
                else
                  if callback != null
                    callback(new Error('Load member data error'))
                  reject()
                return
              )
          )
        getAllMembers = (getMember(id) for id in [1..memberCount-1])
        Promise.all(getAllMembers).then(
          () ->
            if callback != null
              callback(null, self.memberList)
            return
        )
        return
    )

  self.signUp = (type, userName, callback) ->
    ethFunction = null
    if type == 'freelancer'
      ethFunction = self.contracts.member.methods.setSelfAsFreelancer(userName)
    if type == 'shareholder'
      ethFunction = self.contracts.member.methods.setSelfAsPureShareholder(userName)

    if ethFunction == null
      callback(new Error('Invalid type'))
      return
    return web3.eth.getAccounts().then(
      (accounts) ->
        web3.eth.defaultAccount = accounts[0]
        return ethFunction.send({from: web3.eth.defaultAccount, gas: 1000000}).on(
          'receipt',
          (receipt) ->
            if callback != null
              callback(null)
        ).on(
          'error',
          (error) ->
            if callback != null
              callback(error)
        )
    )
  return
