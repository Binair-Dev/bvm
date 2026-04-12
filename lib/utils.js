import { execSync, spawn } from 'child_process';
import fs from 'fs';
import path from 'path';

export const HOME = process.env.HOME || '/data/data/com.termux/files/home';
export const BVM_DIR = path.join(HOME, '.bvm');
export const VMS_FILE = path.join(BVM_DIR, 'vms.json');
export const PROOT_ROOTFS = '/data/data/com.termux/files/usr/var/lib/proot-distro/installed-rootfs';

export function ensureBvmDir() {
  if (!fs.existsSync(BVM_DIR)) {
    fs.mkdirSync(BVM_DIR, { recursive: true });
  }
}

export function readVms() {
  ensureBvmDir();
  if (!fs.existsSync(VMS_FILE)) return [];
  try {
    return JSON.parse(fs.readFileSync(VMS_FILE, 'utf8'));
  } catch {
    return [];
  }
}

export function writeVms(vms) {
  ensureBvmDir();
  fs.writeFileSync(VMS_FILE, JSON.stringify(vms, null, 2));
}

export function getDistroName(vmName) {
  return `bvm-ubuntu-${vmName}`;
}

export function getVmPath(vmName) {
  return path.join(PROOT_ROOTFS, getDistroName(vmName));
}

export function exec(command, options = {}) {
  return execSync(command, { stdio: 'inherit', ...options });
}

export function execPipe(command, options = {}) {
  return execSync(command, { stdio: 'pipe', encoding: 'utf8', ...options });
}

export function hasProotDistro() {
  try {
    execPipe('command -v proot-distro');
    return true;
  } catch {
    return false;
  }
}

export function installProotDistro() {
  console.log('Installing proot-distro...');
  exec('pkg install -y proot-distro');
}

export function vmExists(vmName) {
  const vms = readVms();
  return vms.some(v => v.name === vmName);
}

export function getVm(vmName) {
  const vms = readVms();
  return vms.find(v => v.name === vmName);
}

export function addVm(vmName) {
  const vms = readVms();
  if (!vms.some(v => v.name === vmName)) {
    vms.push({
      name: vmName,
      createdAt: new Date().toISOString(),
      distro: getDistroName(vmName)
    });
    writeVms(vms);
  }
}

export function removeVm(vmName) {
  let vms = readVms();
  vms = vms.filter(v => v.name !== vmName);
  writeVms(vms);
}

export function getVmSize(vmPath) {
  try {
    const out = execPipe(`du -sb "${vmPath}" 2>/dev/null || echo 0`);
    return parseInt(out.split('\t')[0], 10) || 0;
  } catch {
    return 0;
  }
}

export function formatBytes(bytes) {
  if (bytes === 0) return '0 B';
  const k = 1024;
  const sizes = ['B', 'KB', 'MB', 'GB'];
  const i = Math.floor(Math.log(bytes) / Math.log(k));
  return `${(bytes / Math.pow(k, i)).toFixed(2)} ${sizes[i]}`;
}
