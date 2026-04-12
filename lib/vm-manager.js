import { exec, getDistroName, getVmPath, hasProotDistro, installProotDistro, addVm, removeVm, vmExists, getVmSize, formatBytes, readVms } from './utils.js';
import fs from 'fs';

export function createVm(vmName) {
  if (!vmName || !/^[a-zA-Z0-9_-]+$/.test(vmName)) {
    console.error('Invalid VM name. Use only letters, numbers, underscores, and hyphens.');
    process.exit(1);
  }

  if (vmExists(vmName)) {
    console.error(`VM "${vmName}" already exists.`);
    process.exit(1);
  }

  if (!hasProotDistro()) {
    installProotDistro();
  }

  const distroName = getDistroName(vmName);
  console.log(`Creating VM "${vmName}" (distro: ${distroName})...`);

  try {
    exec(`proot-distro install --alias ${distroName} ubuntu`);
    addVm(vmName);
    console.log(`VM "${vmName}" created successfully.`);
  } catch (err) {
    console.error('Failed to create VM:', err.message);
    process.exit(1);
  }
}

export function deleteVm(vmName, force = false) {
  if (!vmExists(vmName)) {
    console.error(`VM "${vmName}" does not exist.`);
    process.exit(1);
  }

  if (!force) {
    console.error('Use --yes to confirm deletion. This will permanently remove the VM and ALL its files.');
    process.exit(1);
  }

  const distroName = getDistroName(vmName);
  console.log(`Deleting VM "${vmName}"...`);

  try {
    exec(`proot-distro remove ${distroName}`);
    removeVm(vmName);
    console.log(`VM "${vmName}" deleted.`);
  } catch (err) {
    console.error('Failed to delete VM:', err.message);
    process.exit(1);
  }
}

export function listVms() {
  const vms = readVms();

  if (vms.length === 0) {
    console.log('No VMs found. Create one with: bvm create <name>');
    return;
  }

  console.log(`\n  Name          Created At                    Size`);
  console.log(`  ${'-'.repeat(60)}`);
  for (const vm of vms) {
    const size = getVmSize(getVmPath(vm.name));
    console.log(`  ${vm.name.padEnd(14)} ${new Date(vm.createdAt).toLocaleString().padEnd(28)} ${formatBytes(size)}`);
  }
  console.log();
}

export function shellVm(vmName) {
  if (!vmExists(vmName)) {
    console.error(`VM "${vmName}" does not exist.`);
    process.exit(1);
  }

  const distroName = getDistroName(vmName);
  const shell = process.env.SHELL || '/bin/bash';
  exec(`proot-distro login ${distroName} -- ${shell} -l`);
}

export function execVm(vmName, command) {
  if (!vmExists(vmName)) {
    console.error(`VM "${vmName}" does not exist.`);
    process.exit(1);
  }

  const distroName = getDistroName(vmName);
  exec(`proot-distro login ${distroName} -- bash -lc "${command.replace(/"/g, '\\"')}"`);
}

export function statusVm(vmName) {
  if (vmName) {
    if (!vmExists(vmName)) {
      console.error(`VM "${vmName}" does not exist.`);
      process.exit(1);
    }
    const exists = fs.existsSync(getVmPath(vmName));
    const size = getVmSize(getVmPath(vmName));
    console.log(`VM: ${vmName}`);
    console.log(`  Rootfs exists: ${exists}`);
    console.log(`  Size: ${formatBytes(size)}`);
  } else {
    console.log(`proot-distro: ${hasProotDistro() ? 'installed' : 'not installed'}`);
    console.log(`Total VMs: ${readVms().length}`);
  }
}
