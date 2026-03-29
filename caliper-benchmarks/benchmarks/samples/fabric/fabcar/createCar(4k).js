'use strict';

const { WorkloadModuleBase } = require('@hyperledger/caliper-core');

const colors = ['blue','red','green','yellow','black','purple','white','violet','indigo','brown'];
const makes  = ['Toyota','Ford','Hyundai','Volkswagen','Tesla','Peugeot','Chery','Fiat','Tata','Holden'];
const models = ['Prius','Mustang','Tucson','Passat','S','205','S22L','Punto','Nano','Barina'];
const owners = ['Tomoko','Brad','Jin Soo','Max','Adrianna','Michel','Aarav','Pari','Valeria','Shotaro'];

/**
 * Target extra payload bytes to push total TX size ≈ 4 KB.
 * For typical Fabcar, 2400–2600 extra bytes gives ~4 KB final size.
 */
const EXTRA_BYTES = parseInt(process.env.EXTRA_BYTES || '2500', 10);

function padField(base, n) {
    if (n <= 0) return base;
    // Add a delimiter then repeat a lightweight character (1 byte per char)
    return `${base}|${'x'.repeat(n)}`;
}

class CreateCarWorkload extends WorkloadModuleBase {
    constructor() {
        super();
        this.txIndex = 0;
    }

    async submitTransaction() {
        this.txIndex++;
        const carNumber = `Client${this.workerIndex}_CAR${this.txIndex}`; // keep key compact

        // Random base values
        let carColor = colors[Math.floor(Math.random() * colors.length)];
        let carMake  = makes[Math.floor(Math.random() * makes.length)];
        let carModel = models[Math.floor(Math.random() * models.length)];
        let carOwner = owners[Math.floor(Math.random() * owners.length)];

        // Distribute padding (~2500 B total)
        const perField = Math.floor(EXTRA_BYTES / 4);
        const remainder = EXTRA_BYTES - 3 * perField;

        carMake  = padField(carMake,  perField);
        carModel = padField(carModel, perField);
        carColor = padField(carColor, perField);
        carOwner = padField(carOwner, remainder);

        const args = {
            contractId: 'fabcar',
            contractVersion: 'v1',
            contractFunction: 'createCar',
            contractArguments: [carNumber, carMake, carModel, carColor, carOwner],
            timeout: 30
        };

        // Optional: log payload size
        // console.log('payload-bytes =', Buffer.byteLength(JSON.stringify(args), 'utf8'));

        await this.sutAdapter.sendRequests(args);
    }
}

function createWorkloadModule() {
    return new CreateCarWorkload();
}

module.exports.createWorkloadModule = createWorkloadModule;

