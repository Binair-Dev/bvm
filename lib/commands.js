import { createVm, deleteVm, listVms, shellVm, execVm, statusVm } from './vm-manager.js';

const USAGE = `
Usage: bvm <command> [options]

Commands:
  create <name>          Create a new Ubuntu VM
  delete <name> --yes    Delete a VM and all its files
  list                   List all VMs
  shell <name>           Open a shell in the VM
  exec <name> <cmd>      Execute a command in the VM
  status [name]          Show status of a VM or bvm itself
  help                   Show this help message

Examples:
  bvm create devbox
  bvm list
  bvm shell devbox
  bvm exec devbox "apt update"
  bvm delete devbox --yes
`;

export function runCli(args) {
  if (args.length === 0 || args[0] === 'help' || args[0] === '--help' || args[0] === '-h') {
    console.log(USAGE);
    process.exit(0);
  }

  const command = args[0];

  switch (command) {
    case 'create': {
      const name = args[1];
      if (!name) {
        console.error('Usage: bvm create <name>');
        process.exit(1);
      }
      createVm(name);
      break;
    }

    case 'delete': {
      const name = args[1];
      const force = args.includes('--yes') || args.includes('-y');
      if (!name) {
        console.error('Usage: bvm delete <name> --yes');
        process.exit(1);
      }
      deleteVm(name, force);
      break;
    }

    case 'list':
      listVms();
      break;

    case 'shell': {
      const name = args[1];
      if (!name) {
        console.error('Usage: bvm shell <name>');
        process.exit(1);
      }
      shellVm(name);
      break;
    }

    case 'exec': {
      const name = args[1];
      const cmd = args.slice(2).join(' ');
      if (!name || !cmd) {
        console.error('Usage: bvm exec <name> <command>');
        process.exit(1);
      }
      execVm(name, cmd);
      break;
    }

    case 'status': {
      const name = args[1];
      statusVm(name);
      break;
    }

    default:
      console.error(`Unknown command: ${command}`);
      console.log(USAGE);
      process.exit(1);
  }
}
