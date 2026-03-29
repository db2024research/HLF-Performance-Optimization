/*
* Licensed under the Apache License, Version 2.0 (the "License");
* you may not use this file except in compliance with the License.
* You may obtain a copy of the License at
*
* http://www.apache.org/licenses/LICENSE-2.0
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the License is distributed on an "AS IS" BASIS,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the License for the specific language governing permissions and
* limitations under the License.
*/

'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

/**
 * This version (v2) is tuned to generate smaller transactions (~0.5 KB effective)
 * by sending shorter arguments to the chaincode.
 * Adjust the string length below if you want even smaller/larger payloads.
 */
class CreateCarWorkloadV2 extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
    }

    /**
     * Assemble TXs for the round.
     * @return {Promise<TxStatus[]>}
     */
    async submitTransaction() {
        this.txIndex++;

        // keep ID short but unique
        const carId = 'C' + this.workerIndex + '_' + this.txIndex; // e.g. C0_15

        // short fields (instead of long random words)
        const make = 'T';       // Toyota -> "T"
        const model = 'M';      // Model -> "M"
        const color = 'B';      // Blue -> "B"
        const owner = 'O';      // Owner -> "O"

        // Optional: add a tiny filler to keep payload stable (around a few dozen bytes)
        // If you really need to hit closer to 512B, increase this to, say, 100–150 chars.
        const filler = 'x'.repeat(80); // 80 bytes extra

        // We keep the original function name/signature to stay compatible with fabcar.
        // fabcar's default createCar usually expects 5 args, so we send 5 here.
        const args = {
            contractId: 'fabcar',
            contractVersion: 'v1',
            contractFunction: 'createCar',
            contractArguments: [carId, make, model, color, owner + '_' + filler],
            timeout: 30
        };

        await this.sutAdapter.sendRequests(args);
    }
}

/**
 * Create a new instance of the workload module.
 * @return {WorkloadModuleInterface}
 */
function createWorkloadModule() {
    return new CreateCarWorkloadV2();
}

module.exports.createWorkloadModule = createWorkloadModule;

