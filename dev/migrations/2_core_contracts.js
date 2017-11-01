// Generated by CoffeeScript 2.0.1
(function() {
  /*
    2_core_contracts.coffee
    Created by Zefram Lou (Zebang Liu) as part of the WikiGit project.

    This file defines the deployment process of the core contracts of
    the DASP. In addition, it initializes the DASP's Git repo,
    publishes it onto the IPFS network, and saves its hash in the
    GitHandler module.
  */
  var dao, fs, git, git_handler, ipfs, ipfsAPI, main, member_handler, tasks_handler, vault;

  //Initialize contract abstractions
  main = artifacts.require('Main');

  dao = artifacts.require('Dao');

  member_handler = artifacts.require('MemberHandler');

  vault = artifacts.require('Vault');

  tasks_handler = artifacts.require('TasksHandler');

  git_handler = artifacts.require('GitHandler');

  //Import node modules
  ipfsAPI = require('ipfs-api');

  ipfs = ipfsAPI('ipfs.infura.io', '5001', {
    protocol: 'https'
  });

  git = require('gift');

  fs = require('fs');

  module.exports = function(deployer) {
    var abiPath;
    abiPath = './build/contracts';
    return ipfs.util.addFromFs(abiPath, {
      recursive: true
    }, function(error, abiFiles) {
      var getABIHash, mainHash;
      if (error !== null) {
        throw error;
      }
      getABIHash = function(modName) {
        var f, i, len;
        for (i = 0, len = abiFiles.length; i < len; i++) {
          f = abiFiles[i];
          //js-ipfs-api bug in Windows
          if (f.path === `D:WebstormProjects/WikiGit/dev/build/contracts/${modName}.json`) {
            return f.hash;
          }
        }
      };
      mainHash = getABIHash('Main');
      //Deploy main contract
      return deployer.deploy(main, 'Test Metadata', mainHash).then(function() {
        var newHash, repoPath;
        repoPath = './tmp/repo.git';
        if (!fs.existsSync(repoPath)) {
          if (!fs.existsSync('./tmp')) {
            fs.mkdirSync('./tmp');
          }
          fs.mkdirSync(repoPath);
        }
        newHash = '';
        //Initialize Git repo
        return git.init(repoPath, true, function(error, _repo) {
          if (error !== null) {
            throw error;
          }
          //Add repo to the IPFS network
          return ipfs.util.addFromFs(repoPath, {
            recursive: true
          }, function(error, result) {
            if (error !== null) {
              throw error;
            }
            //Get repo's IPFS multihash
            newHash = result[result.length - 1].hash;
            //Deploy core modules
            return deployer.deploy([[dao, main.address], [member_handler, 'Test Username', main.address], [vault, main.address], [tasks_handler, main.address], [git_handler, newHash, main.address]]).then(function() {
              //Add core module addresses to main contract
              return main.deployed().then(function(instance) {
                return instance.initializeModuleAddresses([dao.address, member_handler.address, vault.address, tasks_handler.address, git_handler.address]);
              });
            }).then(function() {
              //Initialize the DAO
              return dao.deployed().then(function(instance) {
                return instance.init();
              });
            }).then(function() {
              var modAbsNames;
              //Initialize the ABI hashes
              modAbsNames = ['Dao', 'MemberHandler', 'Vault', 'TasksHandler', 'GitHandler'];
              return main.deployed().then(function(instance) {
                var initABIHashForMod, modId;
                initABIHashForMod = function(modId) {
                  return instance.initializeABIHashForMod(modId, getABIHash(modAbsNames[modId]));
                };
                return Promise.all((function() {
                  var i, results;
                  results = [];
                  for (modId = i = 0; i <= 4; modId = ++i) {
                    results.push(initABIHashForMod(modId));
                  }
                  return results;
                })());
              });
            });
          });
        });
      });
    });
  };

}).call(this);

//# sourceMappingURL=2_core_contracts.js.map
