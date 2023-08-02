import { prismaClient } from './prismaClient';
import { Prisma } from '@prisma/client';
import { DecodedLog } from '../types';

async function writeToDatabase(decodedLogs: DecodedLog[]) {
  for (const log of decodedLogs) {
    if (!log.args) {
      console.log(`Skipping log due to missing args: ${JSON.stringify(log)}`);
      continue;
    }
    console.log(`Processing event: ${log.eventName}`);
    try {
      switch (log.eventName) {
        case 'SetupAP721': {
          const dataAP721: Prisma.AP721CreateInput = {
            ap721: log.args.ap721,
            sender: log.args.sender,
            owner: log.args.initialOwner,
            logic: log.args.logic,
            renderer: log.args.renderer,
            factory: log.args.factory,
            createdAt: log.blockNumber as bigint,
          };
          await prismaClient.aP721.create({ data: dataAP721 });
          console.log('Successfully populated AP721 table.');
          break;
        }
        case 'LogicUpdated': {
          const dataLogicUpdated: Prisma.AP721UpdateInput = {
            logic: log.args.logic,
          };
          await prismaClient.aP721.update({
            where: { ap721: log.args.target },
            data: dataLogicUpdated,
          });
          console.log('Successfully updated AP721 table for LogicUpdated.');
          break;
        }
        case 'RendererUpdated': {
          const dataRendererUpdated: Prisma.AP721UpdateInput = {
            renderer: log.args.renderer,
          };
          await prismaClient.aP721.update({
            where: { ap721: log.args.target },
            data: dataRendererUpdated,
          });
          console.log('Successfully updated AP721 table for RendererUpdated.');
          break;
        }

        case 'DataStored': {
          const dataDataStored: Prisma.TokenStorageCreateInput = {
            ap721: log.args.target,
            tokenId: log.args.tokenId,
            pointer: log.args.pointer,
            updatedAt: log.blockNumber as bigint,
            updatedBy: log.args.sender,
          };
          await prismaClient.tokenStorage.create({
            data: dataDataStored,
          });
          console.log('Successfully populated TokenStorage table.');
          break;
        }

        case 'DataOverwritten': {
          const dataDataOverwritten: Prisma.TokenStorageUpdateInput = {
            pointer: log.args.pointer,
            updatedAt: log.blockNumber as bigint,
            updatedBy: log.args.sender,
          };
          await prismaClient.tokenStorage.update({
            where: {
              ap721: log.args.target,
              tokenId: log.args.tokenId,
            },
            data: dataDataOverwritten,
          });
          console.log('Successfully populated TokenStorage table.');
          break;
        }
      }
    } catch (e) {
      console.error(`Error processing event ${log.eventName}:`, e);
    }
  }
}
