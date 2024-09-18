#!/usr/bin/env python3

from pprint import pprint as pp  # noqa: F401
from functools import reduce, lru_cache
import subprocess
import sys
import re
import os
import time
from concurrent.futures import ThreadPoolExecutor, ProcessPoolExecutor
import logging
import traceback
import operator
import termcolor
from collections import defaultdict, namedtuple, Counter
from datetime import datetime
from tempfile import TemporaryDirectory
from pathlib import Path
import json
from collections.abc import Iterable
from email.message import EmailMessage
import smtplib
import argparse
import socket
import warnings
import csv
import io

from copy import deepcopy
import requests
from PIL import Image
from munch import Munch as BaseMunch
from django.utils.text import slugify
from send_mul_email import build_email_table
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText
# from multimethod import multimethod

# suppressing CryptographyDeprecationWarning for cryptography module, used by pypsexec:
warnings.simplefilter("ignore")
from pypsexec.client import Client

default_cache_time = 24 * 3600  # 24 hours
max_workers = 50  # max parallel threads
max_netbox_connections = 4  # trying not to overload Netbox
defaut_mail_from = "swx-ticket@nvidia.com"
default_cc = ""
smtp_server = "mailgw.nvidia.com"
server_root_password = os.environ.get("SERVER_ROOT_PASSWORD")
switch_admin_password = os.environ.get("SWITCH_ADMIN_PASSWORD")
netbox_api_token = os.environ.get("NETBOX_API_TOKEN")
special_servers = [ "agx-2"]
special_password = "3tango11"
session = requests.Session()
session.headers = {"Authorization":f'Token {netbox_api_token}'}
CableInfo = namedtuple("CableInfo", ["sn", "hostname", "nic", "len"])
ConnectionInfo = namedtuple("ConnectionInfo", ["cable_sn", "port", "other_hostname", "other_port"])
db_conn = None

log = None  # configured later in configure_logging()

# ESXi commands:
esxi_any_command = 'printf "{command} && exit" | sshpass -p {server_root_password} ssh root@{server} 2> /dev/null'

all_connections = None  # global variable, filled in below


def setup_logging(logger_name, level=logging.DEBUG):
    log = logging.getLogger(logger_name)
    log.setLevel(level)
    for handler in log.handlers:
        log.removeHandler(handler)
    ch = logging.StreamHandler(sys.stderr)
    ch.setLevel(level)
    formatter = logging.Formatter('%(asctime)s %(message)s')
    ch.setFormatter(formatter)
    log.addHandler(ch)
    return log


def configure_logging(log_level=logging.INFO):
    global log
    log = setup_logging("NetboxAPI", log_level)
    if log_level == logging.DEBUG:
        setup_logging("urllib3", log_level)


def die(text):
    print(text, file=sys.stderr)
    sys.exit(1)


def system_audit():
    if not (server_root_password and switch_admin_password and netbox_api_token):
        die("You should set SERVER_ROOT_PASSWORD, SWITCH_ADMIN_PASSWORD and NETBOX_API_TOKEN environment variables")

    try:
        system("which fping")
    except subprocess.CalledProcessError:
        die("Cannot find command 'fping', please make sure you have it installed")

    try:
        system("which dot")
    except subprocess.CalledProcessError:
        die("Cannot find command 'dot', please make sure you have graphviz package installed")


class Timer(object):
    def __init__(self, text):
        self.text = text

    def __enter__(self):
        self.start = time.perf_counter()

    def __exit__(self, *args):
        interval = time.perf_counter() - self.start
        log.debug("Timer for %s: %.2f" % (self.text, interval))


class NetboxObject(BaseMunch):
    # fields specific for object type "Device":
    is_available = False
    os = None
    interfaces = []
    contacts = []
    contact_ids = []
    diagram = ""
    connections = []
    cables = []

    def __hash__(self):
        return hash(self.toJSON())

    def __str__(self):
        if getattr(self, "url", None):
            parts = self.url.split("/")
            if "name" in self:
                return f"<{self.name}: {parts[-3]}/{parts[-2]}>"
            else:
                return f"<{parts[-3]}/{parts[-2]}>"
        else:
            return repr(self)

    def __lt__(self, other):
        return self.display < other.display

    def __repr__(self):
        return f"<{self.__class__.__name__} {self.toDict()}>"


class NetboxError(Exception):
    pass


class ObjectNotFound(NetboxError):
    pass


class DeviceNotFound(ObjectNotFound):
    pass


# @lru_cache(maxsize=None)
def cached_get(*args, **kwargs):
    ret = session.get(*args, **kwargs)
    if ret.status_code >= 400:
        print_testing(ret.text)
    ret.raise_for_status()
    return ret.json()


class NetboxClient():
    limit = 1000

    def __init__(self, api_url, api_token, endpoint="dcim"):
        self.api_url = api_url
        self.api_token = api_token
        self.endpoint = endpoint  # "dcim" is default API endpoint, see full list at http://swx-nbx.lab.mtl.com/api/

    def get(self, partial_url=None, full_url=None, **kwargs):
        assert (partial_url and not full_url) or (full_url and not partial_url), \
            "You should specify 'partial_url' or 'full_url', but not both"
        url = full_url or f"{self.api_url}/api/{self.endpoint}/{partial_url}/"
        params = {"limit": self.limit} if partial_url else {}
        params.update(kwargs)
        headers = {"Authorization": f"Token {self.api_token}"}
        try:
            return cached_get(url, params=params, headers=headers)
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 404:
                raise ObjectNotFound() from e
            else:
                raise e

    def post(self, partial_url, json_data=None, form_data=None, files=None):
        url = f"{self.api_url}/api/{self.endpoint}/{partial_url}/"
        ret = session.post(url, json=json_data, data=form_data, files=files)
        if ret.status_code >= 400:
            print_testing(ret.text)
        ret.raise_for_status()
        return NetboxObject.fromDict(ret.json())

    def patch(self, partial_url, json_data=None, form_data=None, files=None):
        url = f"{self.api_url}/api/{self.endpoint}/{partial_url}/"
        ret = session.patch(url, json=json_data, data=form_data, files=files)
        try:
            if ret.status_code >= 400:
                print_testing(ret.text)
            ret.raise_for_status()
        except requests.exceptions.HTTPError as e:
            log.error(f"Netbox API error: {ret.text}")
            raise e
        return NetboxObject.fromDict(ret.json())

    def delete(self, partial_url, object_id):
        url = f"{self.api_url}/api/{self.endpoint}/{partial_url}/{object_id}/"
        ret = session.delete(url)
        if ret.status_code >= 400:
            print_testing(ret.text)
        ret.raise_for_status()

    def create_interface(self, device, name, cable_sn=None,isvms=False, **kwargs):
        if isvms:
            existing = self.virtualization.interfaces(virtual_machine_id=device.id, name=name)
        else:
            existing = self.interfaces(device_id=device.id, name=name)
        if existing:
            # raise NetboxError(f"Interface {name} already exists in {device}")
            return existing[0]

        log.info(f"Creating interface {name} for {device}, cable S/N {cable_sn}, additional params: {kwargs}")
        data = {
            "name": name,
            "device": device.id,
            "type": "other",
            "custom_fields": {
                "auto_discovered": True,
                "cable_sn": cable_sn,
            },
        }
        if isvms:
            data = {
                "virtual_machine": {
                        "name": device.name,
                        "id": device.id,
                        },
                "name": name,
                "enabled": True,
                "custom_fields": {
                    "auto_discovered": True,
                    "cable_sn": cable_sn,
            },
            }
        data.update(kwargs)
        if isvms:
            return self.virtualization.post("interfaces",json_data=data)
        else:
             return self.post("interfaces",json_data=data)
        

    def create_cable(self, a_terminations, b_terminations, cable_sn):
        log.info(f"Creating connection between {[i.id for i in a_terminations]} and {[i.id for i in b_terminations]}, cable S/N {cable_sn}")
        data = {            
            "a_terminations": [{"object_type": "dcim.interface", "object_id": i.id} for i in a_terminations],
            "b_terminations": [{"object_type": "dcim.interface", "object_id": i.id} for i in b_terminations],
            "custom_fields": {
                "auto_discovered": True,
                "cable_sn": cable_sn,
            },
        }
        try:
            return self.post("cables", json_data=data)
        except requests.exceptions.HTTPError as e:
            if e.response.status_code == 500:
                log.error(f"The connection seems to be already existing, Netbox API returned {e}")
            else:
                raise e

    def delete_interface(self, iface):
        log.info(f"Removing interface {iface}")
        self.delete("interfaces", iface.id)

    def delete_cable(self, cable):
        self.delete("cables", cable.id)
    
    def check_vm(self, name):
        data = self.virtualization.virtual_machines(name=name)
        if len(data) > 0:
                return data[0]
        data = [d for d in self.devices() if slugify(d.name) == slugify(name)]
        if len(data) > 0:
            return data[0]
    @lru_cache(10000)
    def get_device_by_name(self, name):
        # it is nice to be able to use this method with Netbox objects as well:
        if type(name) is NetboxObject:
            return name

        data = self.devices(name=name)
        if len(data) > 0:
            return data[0]
        else:
            # trying to find objects with the same slug (URL-safe object identifier)
            # slugify converts string like "Leaf SWITCH 1" to "leaf-switch-1"
            data = [d for d in self.devices() if slugify(d.name) == slugify(name)]
            if len(data) > 0:
                return data[0]
            else:
                vm = self.check_vm(name)
                if vm:
                   return vm
                raise DeviceNotFound(f"Cannot find device by name or slug '{name}'")

        
    def get_device_interfaces(self, device):
        if is_vm(device):
            return self.virtualization.interfaces(virtual_machine_id=device.id)
        return self.interfaces(device_id=device.id)

    def get_device_images(self, device):
        # FIXME: object_id has two incompatible semantics:
        # return self.extras.image_attachments(content_type="dcim.device", object_id=device.id)
        data = self.extras.get(partial_url="image-attachments", content_type="dcim.device", object_id=device.id)
        return [NetboxObject.fromDict(o) for o in data["results"]]

    def upload_device_image(self, device, image_fn):
        img = Image.open(image_fn)
        now = datetime.now().isoformat(timespec="seconds")
        self.extras.post(
            "image-attachments",
            form_data={
                "object_type": "dcim.device",
                "object_id": device.id,
                "name": image_fn.stem,
                "image_width": img.size[0],
                "image_height": img.size[1],
                "custom_fields.created_by": "netbox.py",               
            },
            files={"image": open(image_fn, "rb")},
        )

    def delete_device_image(self, image):
        log.info(f"Deleting device image {image.image}")
        self.extras.delete("image-attachments", image.id)

    def api_call(self, api_method, _object_id=None, **kwargs):
        if _object_id:
            return NetboxObject.fromDict(self.get(partial_url=f"{api_method}/{_object_id}", **kwargs))
        else:
            # requesting paged dataset:
            results = []
            data = self.get(partial_url=api_method, **kwargs)
            results += data["results"]
            while data["next"]:
                data = self.get(full_url=data["next"])
                results += data["results"]
            return [NetboxObject.fromDict(o) for o in results]

    def __getattr__(self, prop_name, *args, **kwargs):
        if prop_name.startswith("__"):
            raise AttributeError(f"{self} object does not have attribute {prop_name}")
        else:
            if prop_name in ["circuits", "extras", "dcim", "ipam", "plugins", "status", "tenancy", "users", "virtualization", "wireless"]:
                return NetboxClient(self.api_url, self.api_token, endpoint=prop_name)
            else:
                def handler(*args, **kwargs):
                    return self.api_call(prop_name.replace("_", "-"), *args, **kwargs)
                return handler

    def enriched_devices(self, *args, **kwargs):
        ret = self.devices(*args, **kwargs)
        enrich(ret)
        return ret

    @lru_cache(1000)
    def cables_cached(self, *args, **kwargs):
        return self.cables(*args, **kwargs)

    @lru_cache(1000)
    def interfaces_cached(self, *args, **kwargs):
        return self.interfaces(*args, **kwargs)


def system(cmd, ignore_errors=False):
    log.debug(f"Running command: {cmd}")
    try:
        return subprocess.check_output(cmd, stderr=subprocess.STDOUT, shell=True).decode("utf-8").strip()
    except subprocess.CalledProcessError as e:
        log.debug(e)
        if not ignore_errors:
            raise(e)
        
def get_data_from_switch(hostname, variable):

    cmd = f"""
            timeout {default_cache_time} sshpass -p admin ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -oKexAlgorithms=+diffie-hellman-group14-sha1 admin@{hostname} << EOF
            enable
            show version
            EOF"""
    try:
        output = system(cmd)
    except Exception as e:
        log.error(f"Error getting data from {hostname}: {str(e)}")
        return None
    print(output)
    for line in output.splitlines():
        if variable in line:
            os_name = line.split(':')[1].strip()
            return os_name

# def host_accessible(device):
#     if check_access(device):
#         return device.name

def enrich_with_availability(devices):
    hosts = "\n".join([d.name for d in devices if d.name])  # skip devices with None as name
    res = system(f"printf '{hosts}' | fping -a 2>/dev/null || true")
    data = res.splitlines()
    for d in devices:
        d.is_available = d.name in data  # and check_access(d)


# @cache.memoize(expire=default_cache_time, tag="ping")
def host_available(device):
    hostname = device
    if isinstance(device, NetboxObject):
        hostname = device.name
    try:
        system(f"ping -W2 -c1 {hostname} >/dev/null 2>&1")
        return True
    except subprocess.CalledProcessError:
        pass


def detect_windows(hostname):
    c = Client(hostname, username=".\\Administrator", password=server_root_password)
    try:
        c.connect()
        try:
            c.create_service()
            os_name = 'windows'
            c.remove_service()
            return os_name
        except Exception:
            pass
        finally:
            c.disconnect()
    except Exception:
        pass


def detect_linux(hostname):
    if is_switch(hostname):
            print_testing(f"{hostname} is a switch")
            return get_data_from_switch(hostname, 'Version summary')
    try:
        cmd = r'printf "grep ^ID= /etc/*release"'
        # try to detect Linux distribution
        output = ssh(hostname, cmd)
        if output:
            os_name = output.split('=')[-1].strip('"')
            return os_name

    except subprocess.CalledProcessError as e:
        print_warning(f"{e}")
        pass
    


def detect_esxi(hostname):
    try:
        output = ssh(hostname, r'printf "esxcli system version get"')
        if output and 'VMware ESXi' in output:
            os_name = 'esxi'
            return os_name
    except subprocess.CalledProcessError as e:
        print_testing(f"{e}")
        pass


def get_os(device):
    hostname = device
    if type(device) is NetboxObject:
        hostname = device.name
    """Detect and return OS name: 'rhel', 'centos', 'ubuntu', 'wrlinux', 'windows', 'esxi' or None"""
    os_name = None
    if device.is_available:
        os_name = detect_linux(hostname) or detect_windows(hostname) or detect_esxi(hostname)
        log.debug(f"Detected OS {os_name} for {hostname}")
    return os_name


def get_os_pretty_name(device):
    if get_os_family(device.os) == "unix":
        cmd = "echo grep -h ^PRETTY_NAME '/etc/*release'"
        output = ssh(device.name, cmd)
        if output:
            return output.split('=')[-1].strip('"')


def get_cables(device):
    ret = None
    hostname = device.name

    if not is_valid_hostname(hostname):
        log.debug(f"'{hostname} is not a valid host name, skipping device")
        return []
    print(f"Getting cables from {hostname}")
    log.debug(f"Fetching cables from {hostname}")
    if is_switch(device):
        print(f"{hostname} is a switch")
        ret = get_cables_switch(hostname)
    else:
        print(f"{hostname} is not a switch")
        os_family = get_os_family(device.os)
        if os_family == "unix":
            ret = get_cables_linux(device)
        elif os_family == "windows":
            ret = get_cables_windows(hostname)
        elif os_family == "esxi":
            ret = get_cables_esxi(hostname)
        else:
            log.debug(f"Unknown OS family on {hostname}: {os_family}")

    if ret:
        ret = [cable for cable in ret if cable.sn and "n/a" not in cable.sn.lower()]

    return ret or []


def get_cables_switch(hostname):
    ret = []

    log.debug(f"Fetching cables and ports from {hostname}")
    # if hostname is a infiniband switch, we need an other cmd
    output = ssh(hostname, r'printf "en\nsh interfaces ethernet transceiver brief | include Eth\n"')
    if output:
        for line in output.splitlines():
            match = re.search(r"^(Eth[\d/]+).*\s+(MT\w+)\s+", line)
            if match:
                port, cable_sn = match.groups()
                ret.append(CableInfo(cable_sn, hostname, port, ""))
    return ret


def get_switch_free_ports(hostname):
    ret = []

    log.debug(f"Fetching free ports from {hostname}")
    output = ssh(hostname, r'printf "en\nsh interfaces ethernet transceiver brief | include Eth\n"', user="admin", password=switch_admin_password)
    if output:
        for line in output.splitlines():
            match = re.search(r"^(Eth[\d/]+)$", line)
            if match:
                ret.append(match.groups()[0])
    return ret


def safe_load_json(string):
    if string:
        try:
            return json.loads(string)
        except json.decoder.JSONDecodeError as e:
            log.debug(f"Cannot decode JSON string '{string[:50]}', error: '{e}'")


def get_lshca(device):
    cmd = "echo /hpc/local/bin/lshca.bin -w cable -j"
    data = safe_load_json(ssh(device.name, cmd, ignore_errors=True))
    return data or []


def get_nvidia_gpus(device):
    cmd = "echo nvidia-smi --format=csv,noheader --query-gpu=name,serial"
    res = ssh(device.name, cmd)
    for row in csv.reader(io.StringIO(res)):
        if len(row) >= 2:
            yield {
                "gpu_name": row[0].strip(),
                "gpu_serial": row[1].strip(),
            }


def get_system_sn(device):
    """ getting a chassis serial number """
    # both "lshw -xml" and "lshw -json" do not produce well-formed output,
    # so we should parse text output here:
    output = ssh(device.name, "echo lshw -quiet -class system")
    if output:
        for line in output.splitlines():
            if line.strip().lower().startswith("serial:"):
                return line.split()[1]


def get_drives(device):
    output = ssh(device.name, "echo lshw -quiet -class storage,disk")
    ret = []
    info = {}

    def drive_info(info):
        if info.get("type") in ["disk", "nvme"]:
            if "description" in info and "product" in info:
                if "removable" not in info.get("capabilities", ""):
                    res = {
                        "description": info["description"],
                        "product": info["product"],
                    }
                    if "serial" in info:
                        res["serial"] = info["serial"]
                    if "size" in info:
                        res["size"] = info["size"]
                    return res

    if output:        
        for line in output.splitlines():
            line = line.strip()
            if line.startswith("*-"):
                if drive_info(info):
                    ret.append(drive_info(info))
                info = {"type": re.sub('[\W\d]+', '', line)}
                continue
            parts = line.split(":")
            info[parts[0].lower()] = ":".join(parts[1:]).strip()
        ret.append(drive_info(info))

    return [d for d in ret if d]

# def get_gpus(device):
#     cmd = "echo lshw -class display -json"
#     return safe_load_json(ssh(device.name, cmd, ignore_errors=True)) or []


# def get_nvidia_gpus(device):
#     ret = []
#     return [gpu for gpu in get_gpus(device) if "nvidia" in gpu.get("vendor", "").lower()]

def get_max_speed(lspci_data):
    speed = []
    for line in lspci_data.split("\n"):
        if line.startswith("\t\tLnkCap:"):
            speed.append(float(line.split(",")[1].split(" ")[2][:-4]))
            
    if speed:
        return max(speed)

def get_lspci(device):
    cmd = "echo lspci -vvv"
    try:
      data = ssh(device.name, cmd)
    except:
        return None
    if data:
        return data
    
def get_pci_gen(device):
    pci_gens = {2.5: "",5: "2.0",8: "3.0",16: "4.0",32: "5.0",64: "6.0",128: "7.0"}
    pci_gens = {2.5: "PCIe Gen 1", 5: "PCIe Gen 2", 8: "PCIe Gen 3",\
        16: "PCIe Gen 4", 32: "PCIe Gen 5", 64: "PCIe Gen 6", 128: "PCIe Gen 7"}
    data = get_lspci(device)
    if data:
        try:
            print_warning("THIS should be the pci gen",pci_gens[get_max_speed(data)])
            return pci_gens[get_max_speed(data)]
        except Exception as e:
            print(data)


def get_cables_linux(device):
    hostname = device.name
    ret = None

    data = get_lshca(device)
    if data:
        ret = []
        for nic in data:
            for cable in nic.get("bdf_devices", []):
                if cable.get("Net"):
                    ret.append(CableInfo(
                        sn=cable.get("CblSN"),
                        hostname=hostname,
                        nic=cable.get("RDMA", cable.get("Net")),
                        len=cable.get("CblLng"),
                    ))
    return ret


def get_os_family(os_name):
    if os_name in ["ubuntu", "debian", "centos", "rhel", "ol", "fedora", "sles", "freebsd"]:
        return "unix"
    else:
        return os_name


def parse_mlxcables_output(text):
    ret = {}
    fields = ["Cable name", "Serial number", "Part number", "Length"]
    for line in text.splitlines():
        if " : " in line:
            try:
                key, value = line.split(":")[:2]
                for f in fields:
                    if key.startswith(f):
                        ret[f] = value.strip()
            except Exception:
                pass
    return ret


def win_execute(hostname, cmd):
    """
    This is a wrapper for a function _win_execute() which does the actual job. The wrapper
    function runs _win_execute() in a separate process to handle all the issues related to pypsexec,
    mainly the error "Exception calling RDeleteService. Code: 1072, Msg: ERROR_SERVICE_MARKED_FOR_DELETE"
    """
    with ProcessPoolExecutor(max_workers=1) as executor:
        res = list(executor.map(_win_execute, [hostname], [cmd]))
        if res:
            return res[0]


def _win_execute(hostname, cmd):
    log.debug(f"Executing '{cmd}' on '{hostname}'")
    try:
        c = Client(hostname, username="Administrator", password=server_root_password)
        try:
            c.connect()
        except Exception as e:
            log.debug(f"Error in win_execute({hostname}, {cmd}): connect() failed with a following error: {e}")
        c.create_service()
        full_cmd = f"/c {cmd}"
        stdout, stderr, rc = c.run_executable('cmd.exe', arguments=full_cmd)
        if rc > 0:
            stderr = stderr.decode("utf-8")
            log.debug(f"Windows command '{cmd}' returned {rc}, stderr: {stderr}")
        return stdout.decode("utf-8")
    except Exception as e:
        log.debug(f"Error in win_execute({hostname}, {cmd}): {e}")
        traceback.print_tb(e.__traceback__)
    finally:
        try:
            c.remove_service()
            c.disconnect()
        except Exception:
            pass


def get_cables_windows(hostname):
    ret = []
    win_execute(hostname, '"C:\\Program Files\\Mellanox\\WinMFT\\mst.exe" cable add')
    stdout = win_execute(hostname, '"C:\\Program Files\\Mellanox\\WinMFT\\mst.exe" status -v')
    if stdout:
        cables = [line.strip() for line in stdout.splitlines() if '_cable_' in line]
        for cable in cables:
            cmd = f'"C:\\Program Files\\Mellanox\\WinMFT\\mlxcables.bat" -d {cable}'
            stdout = win_execute(hostname, cmd)
            data = parse_mlxcables_output(stdout)
            if "Serial number" in data:
                ret.append(CableInfo(data["Serial number"], hostname, data.get("Cable name"), data.get("Length")))
    return ret


def get_cables_esxi(hostname):
    ret = None
    install_cmd = esxi_any_command.format(
        command='/mswg/release/mft/mft-4.16.0/mft-4.16.0-54/vmware/install.sh --extra-pkgs-only',
        server=hostname,
        server_root_password=server_root_password,
    )
    try:
        subprocess.check_output(install_cmd, shell=True)
    except subprocess.CalledProcessError:
        pass
    cable_add_cmd = esxi_any_command.format(
        command='/opt/mellanox/bin/mst cable add',
        server=hostname,
        server_root_password=server_root_password,
    )
    try:
        subprocess.check_output(cable_add_cmd, shell=True)
    except subprocess.CalledProcessError:
        return None
    cable_list_cmd = esxi_any_command.format(
        command='/opt/mellanox/bin/mst status -v',
        server=hostname,
        server_root_password=server_root_password,
    )
    try:
        ret = []
        stdout = subprocess.check_output(cable_list_cmd, shell=True).decode("utf-8")
        cables = [line.strip() for line in stdout.splitlines() if '_cable_' in line]
        for cable in cables:
            cable_info_cmd = esxi_any_command.format(
                command='/tmp/mellanox/bin/mlxcables -d {}'.format(cable),
                server=hostname,
                server_root_password=server_root_password,
            )
            stdout = subprocess.check_output(cable_info_cmd, shell=True).decode("utf-8")
            data = parse_mlxcables_output(stdout)
            ret.append(CableInfo(data["Serial number"], hostname, data["Cable name"], data["Length"]))
        return ret
    except subprocess.CalledProcessError:
        return None


def ssh(host, cmd, user="root", password=None, ignore_errors=False, timeout=60, only_check=False):
    password = password or server_root_password
    if is_switch(host):
        password = switch_admin_password
        user = "admin"
    # KexAlgorithms option is required to connect to Mellanox switches, like sw-xlio:
    full_cmd = cmd + f" | timeout {timeout} sshpass -p {password} ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10 -oKexAlgorithms=+diffie-hellman-group14-sha1 {user}@{host}"
    if not is_switch(host):
        # skipping MOTD on Linux hosts:
        full_cmd += " /bin/bash "
    full_cmd +=   " 2>/dev/null"
    output = None
    try:
        
        output = system(full_cmd, ignore_errors=ignore_errors)
        if output:
            return output.strip()
    except subprocess.CalledProcessError as e:
        if output:
            print(output, file=sys.stderr)
        log.debug(f"Command '{cmd}' has failed on '{host}': {e}")
        if e.returncode <= 5:
            print_warning(f"Failed to connect to '{host}' with error code {e.returncode}")
            return None

        if only_check:
            return e
        log.debug(f"Command '{cmd}' has failed on '{host}': {e}")
        # print_warning(f"Failed to connect to '{host}' {e}")


def is_switch(device):
    if type(device) is str:
        device = nb.get_device_by_name(device)
    return hasattr(device, 'device_type') and device.device_type and "switch" in device.role.name.lower()

def is_vm(device):
    return device.url.startswith(f"{nb.api_url}/api/virtualization/virtual-machines") or device["role"]["name"] == "Virtual machine" 
    

def invert(dictionary):
    # helper function to search in dictionary by value
    return {v: k for k, v in dictionary.items()}


def is_valid_hostname(hostname):
    return re.match(r"^[\w\.-]+$", hostname)


def enrich_with_diagram(devices):
    def get_shape(device):
        return "rect" if is_switch(device) else "oval"

    for d in devices:
        lines = []
        lines.append("graph network_diagram {")
        lines.append("graph[rankdir=LR, center=true, margin=0.2, nodesep=0.2, ranksep=0.3]")
        for _, port, other_device, other_port in d.connections:
            lines.append(f'"{d.name}" [ shape={get_shape(d)} ];')
            lines.append(f'"{other_device.name}" [ shape={get_shape(other_device)} ];')
            lines.append(f'"{d.name}" -- "{other_device.name}" [ label="{port} - {other_port}" ];')
        lines.append("}")
        d.diagram = "\n".join(lines)


def dot_notation(connections):
    lines = []
    lines.append("graph network_diagram {")
    # ret += "  graph [rankdir=LR];\n"
    lines.append("graph[rankdir=LR, center=true, margin=0.2, nodesep=0.2, ranksep=0.3]")
    # for k, v in connections.items():
    for switch, sw_port, hostname, iface in connections:
        # lines.append(f'"{switch}" [ shape=rect bgcolor="#cccccc" label=<<b>{switch}</b>>];')
        lines.append(f'"{switch}" [ shape=rect ];')
        # shape = "rect" if "sw" in hostname.lower() else "oval"
        if "sw" in hostname.lower():
            lines.append(f'"{hostname}" [ shape=rect ];')
        else:
            lines.append(f'"{hostname}" [ shape=oval ];')
        # if get_os(hostname):
        #     lines.append(f'"{switch}" -- "{hostname} ({get_os(hostname)})" [ label="{sw_port} - {iface}" ];')
        # else:
        #     lines.append(f'"{switch}" -- "{hostname}" [ label="{sw_port} - {iface}" ];')
        lines.append(f'"{switch}" -- "{hostname}" [ label="{sw_port} - {iface}" ];')
        # ret += f'   "{switch}" -- "{hostname}" [ headlabel="{sw_port}", taillabel="{iface}" ];\n'
    lines.append("}")
    return "\n".join(lines)


def enrich_with_connections(devices):
    switches = set([d for d in devices if is_switch(d)])
    non_switches = set(devices) - switches
    devices_sorted = list(switches) + list(non_switches)
    all_devices = nb.devices()
    enrich_with_cables(all_devices)
    # glossary: ld, rd - left and right device; lc, rc - left and right cable
    for ld in devices_sorted:
        ld.connections = []
        for lc in ld.cables:
            if lc.sn:
                for rd in all_devices:
                    if rd.name != ld.name:
                        for rc in rd.cables:
                            if lc.sn == rc.sn:
                                ld.connections.append(ConnectionInfo(lc.sn, lc.nic, rd, rc.nic))
                                break  # a fix against doubling split cables on a digram


def filter_connections(connections, filter_by=[]):
    dev_names = [d.name for d in filter_by]
    return {k: v for k, v in connections.items() if k[0] in dev_names or k[2] in dev_names}


def enrich_with_os(devices):
    #&! need to test if OS is null?
    for d in devices:
        if d.custom_fields:
            d.os = d.custom_fields.inventory_os
            d.os_pretty_name = d.custom_fields.os_pretty_name
        else:
            d.os , d.os_pretty_name = None, None


# @multimethod
# def enrich(device: NetboxObject):
#     enrich([device])

# @multimethod
def enrich(devices: Iterable, in_progress=False):
    if not in_progress:
        enrich_with_availability(devices)
        enrich_with_os(devices)
    enrich_with_contacts(devices)
    enrich_with_interfaces(devices)
    enrich_with_cables(devices)
    enrich_with_connections(devices)  # should go after enrich_with_cables()
    enrich_with_diagram(devices)


def flatten(list_of_lists):
    list_of_lists = list(list_of_lists)
    if list_of_lists and list_of_lists[0]:
        return reduce(operator.iadd, list_of_lists)  # calling list() in case if `list_of_lists` is an iterator
    else:
        return []


def update_diagrams(devices):
    enrich(devices, in_progress=True)

    def update_device_diagram(device):

        log.debug(f"Updating diagram for {device}")
        # delete current connections diagram:
        for img in nb.get_device_images(device):
            if img.name == "connections":
                nb.delete_device_image(img)

        # create and upload new diagram:
        if device.diagram:
            with TemporaryDirectory() as tmp_dir:
                png_fn = save_diagram(device.diagram, tmp_dir)
                log.info(f"Uploading {png_fn} as an image for device {device}")
                nb.upload_device_image(device, png_fn)

    devices = [d for d in devices if is_switch(d)]

    parallel(update_device_diagram, devices, max_workers=max_netbox_connections)


def save_diagram(connections, directory):
    dot_fn = Path(directory) / "connections.dot"
    with open(dot_fn, "w") as dot_file:
        dot_file.write(connections)
    png_fn = Path(directory) / "connections.png"
    try:
        system(f"dot -Tpng < {dot_fn} > {png_fn}")
    except subprocess.CalledProcessError as e:
        # preventing removing of temp directory:
        log.error(f"Error while saving diagram: {e}")
        os._exit(1)
    return png_fn


def match_interface_names(iface1, iface2):
    """ Matches different style interface names, like "qsfp12" and "Eth1/12" """
    iface1, iface2 = iface1.lower(), iface2.lower()
    # always skip MGMT1 interface:
    if "mgmt" in iface1 or "mgmt" in iface2:
        return False
    if iface1 == iface2:
        return True
    pattern = re.compile(r'^\D+(\d/)?(\d+)(/\d)?$')
    match1 = pattern.search(iface1)
    match2 = pattern.search(iface2)
    return match1 and match2 and match1.groups()[1] == match2.groups()[1]


def find_matching_interface(device, internal_port_name):
    """Switch interfaces are already manually created in Netbox and
    their names do not match auto-discovered name (like "qsfp12" vs "Eth1/12")
    """
    # for iface in nb.get_device_interfaces(device):
    for iface in device.interfaces:
        if match_interface_names(internal_port_name, iface.name):
            return iface


def enrich_with_contacts(devices):
    all_assignements = nb.tenancy.contact_assignments()
    for d in devices:
        d.contact_ids = sorted([ca.contact.id for ca in all_assignements if ca.object_id == d.id])
        d.contacts = [ca.display for ca in all_assignements if ca.object_id == d.id]


def enrich_with_interfaces(devices, isvm=False):
    if len(devices) > 15:
        # get ALL interfaces from Netbox and match them to devices (faster for bulk operations):
        devices_by_id = {d.id: d for d in devices}

        for d in devices:
            d.interfaces = []

        for iface in nb.interfaces_cached():
            if iface.device.id in devices_by_id:
                devices_by_id[iface.device.id].interfaces.append(iface)
    else:
        # get interfaces for devices one by one (faster for small batches, up to 10-20 devices):
        for d in devices:
            if isvm:
                d.interfaces = nb.virtualization.interfaces(device_id=d.id)
                continue
            d.interfaces = nb.interfaces(device_id=d.id)


def update_contact_info(devices):
    enrich_with_contacts(devices)    
    for d in devices:
        new_contacts = set(d.contacts)
        old_contacts = set()
        if d.custom_fields.get("contacts"):
            old_contacts = set(d.custom_fields.get("contacts", {}).get("display", []))
        if new_contacts != old_contacts:
            log.info(f"Contacts for {d} have been changed, updating custom field data")
            notify_on_contact_change(d)
            now = datetime.now().isoformat(timespec="seconds")
            new_contacts = {"display": d.contacts, "ids": d.contact_ids, "updated_at": now}
            nb.patch(f"devices/{d.id}", json_data={"custom_fields": {"contacts": new_contacts}})


def notify_on_contact_change(device):
    new_contact_ids = set(device.contact_ids)
    old_contact_ids = set()
    old_contacts = set()
    if device.custom_fields.get("contacts", {}):
        old_contact_ids = set(device.custom_fields.get("contacts", {}).get("ids", []))
        old_contacts = set(device.custom_fields.get("contacts", {}).get("display", []))
    for contact_id in new_contact_ids | old_contact_ids:
        try:
            contact = nb.tenancy.contacts(contact_id)
            log.info(f"Notifying {contact} on contact change for {device}")
            if "email" in contact:
                text = f"""Hi! This is an automated message from our inventory system Netbox.

Server {device.display} contacts have been changed.

Old contacts: {', '.join(old_contacts)}
New contacts: {', '.join(device.contacts)}

Device details: http://swx-nbx.lab.mtl.com/dcim/devices/{device.id}/"""
                send_mail(mail_to=contact.email, subject=f"[NetBox] [contacts_change] {device.display}", body=text)
        except ObjectNotFound:
            pass
        except Exception as e:
            log.error(f"Error while sending notification to contact {contact_id} about {device}: {e}")


def send_mail(mail_from=defaut_mail_from, mail_to=None, subject=None, body=None, ishtml=False, cc=default_cc):
    log.debug(f"Sending email message to {mail_to}")
    server = smtplib.SMTP(smtp_server)
    # server.set_debuglevel(1)  # uncomment for debug

    if ishtml:
        msg = MIMEMultipart('alternative')
        # Create the HTML part
        html_part = MIMEText(body, 'html')
        # Attach HTML part into message container.
        msg.attach(html_part)
    else:
        msg = EmailMessage()
        msg.set_content(body)

    msg["Subject"] = subject
    msg["From"] = mail_from
    msg["To"] = mail_to
    msg["cc"] = cc
    try:
      server.send_message(msg)
    except Exception as e:
        print_warning(e)
    
    server.quit()


def parallel(func, *args, max_workers=max_workers):
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        return list(executor.map(func, *args))


def create_virtual_interfaces_on_switches(devices):
    def get_virtual_cables(device):
        # lists cables shown in more than one ports on switch (split cables)
        top_sn = [sn for sn, num in Counter([c.sn for c in device.cables]).most_common() if num > 1]
        return [c for c in device.cables if c.sn in top_sn]

    log.info("Creating virtual interfaces on switches for split cables")
    devices = [d for d in devices if is_switch(d)]
    for d in devices:
        for cable in get_virtual_cables(d):
            parent_iface = find_matching_interface(d, cable.nic)
            nb.create_interface(d, cable.nic, cable_sn=cable.sn,
                description=f"Virtual interface on {parent_iface.get('display')} for split cable {cable.sn}")


def create_missing_interfaces(devices, isvms=False):
    def is_valid_nic(nic_name):
        return "n/a" not in nic_name.lower()

    # log.info("Creating missing interfaces")
    # devices = [d for d in devices if is_switch(d)]

    for d in devices:
        for cable in d.cables:
            if cable.nic and is_valid_nic(cable.nic):
                if is_switch(d):
                    iface = find_matching_interface(d, cable.nic)
                    if not iface:
                        nb.create_interface(d, cable.nic, cable_sn=cable.sn, isvms=isvms)
                else:
                    nb.create_interface(d, cable.nic, cable_sn=cable.sn, isvms=isvms)


def update_cable_sn_on_switches(devices):
    def update_device(device):
        for iface in device.interfaces:
            update_iface(iface, match_iface_to_cable(iface, device.cables))

    def update_iface(iface, cable):
        cable_sn = None
        if cable:
            cable_sn = cable.sn
        if iface.custom_fields.cable_sn != cable_sn:
            log.info(f"Updating cable S/N {cable_sn} on {iface}")
            nb.patch(f"interfaces/{iface.id}", json_data={"custom_fields": {"cable_sn": cable_sn}})

    def match_iface_to_cable(iface, cables):
        for cable in cables:
            if iface.name == cable.nic:
                return cable
            if match_interface_names(iface.name, cable.nic):
                return cable

    log.info("Updating cables S/N on switches")
    devices = [d for d in devices if is_switch(d)]
    parallel(update_device, devices, max_workers=max_netbox_connections)


def update_interfaces(devices, isvm=False):
    def is_valid_nic(nic_name):
        return "n/a" not in nic_name.lower()
    
    if isvm:
        for d in devices:
            if get_json_comment(d):
                d.custom_fields = json.loads(d.comments)["custom_fields"]
            else:
                  d.custom_fields = {}

    enrich_with_interfaces(devices, isvm=isvm)
    enrich_with_cables(devices, isvms=isvm)

    create_virtual_interfaces_on_switches(devices)
    create_missing_interfaces(devices, isvms=isvm)
    update_cable_sn_on_switches(devices)

    ifaces_by_cable = defaultdict(list)
    for i in nb.interfaces_cached():
        ifaces_by_cable[i.custom_fields.cable_sn].append(i)

    log.info("Creating connections between interfaces")
    last_created = []
    for d in devices:
        
        for cable in d.cables:
            matching_local_ifaces = [i for i in ifaces_by_cable[cable.sn] if i.device.id == d.id and not i.cable]
            for iface_a in matching_local_ifaces:
                # matching_remote_ifaces = [i for i in ifaces_by_cable[cable.sn] if i.device.id != d.id and not i.cable]
                matching_remote_ifaces = [i for i in ifaces_by_cable[cable.sn] if i.id not in last_created and i.id != iface_a.id and not i.cable]
                # for iface_b in matching_remote_ifaces:
                #     nb.create_cable([iface_a], [iface_b], cable.sn)
                for i in range(min(len(matching_remote_ifaces), len(matching_local_ifaces))) :
                    if (iface_a.id and matching_remote_ifaces[i].id) not in last_created:
                        nb.create_cable([iface_a], [matching_remote_ifaces[i]], cable.sn)
                        last_created.append(iface_a.id)
                        last_created.append(matching_remote_ifaces[i].id)

def cleanup(devices):
    log.info("Deleting auto-discovered interfaces")
    parallel(nb.delete_interface, \
        nb.interfaces(cf_auto_discovered=True, device_id=[d.id for d in devices]), \
        max_workers=max_netbox_connections)
    log.info("Deleting auto-discovered cables")
    parallel(nb.delete_cable, \
        nb.cables(cf_auto_discovered=True, device_id=[d.id for d in devices]), \
        max_workers=max_netbox_connections)


def enrich_with_cables(devices, isvms=False):
    for d in devices:
        if isvms:
            if get_json_comment(d):
                cables = json.loads(d["comments"])["cables"]
            else:
                cables = []
        else:
            cables = d.custom_fields["cables"] or []
        d.cables = [CableInfo(**c) for c in cables]
        if len(devices) < 10:
            print_testing(f"number of cables {len(d.cables)}")


def update_os(devices):
    def update_device(d):
        if d.os != d.custom_fields.inventory_os or d.os_pretty_name != d.custom_fields.os_pretty_name:
            log.info(f"Updating OS for {d}")
            nb.patch(f"devices/{d.id}", json_data={"custom_fields": {
                "inventory_os": d.os,
                "os_pretty_name": d.os_pretty_name,
            }})

    def get_os_info(d):
        d.os = get_os(d)
        d.os_pretty_name = get_os_pretty_name(d)

    enrich_with_availability(devices)
    devices = [d for d in devices if d.is_available]
    parallel(get_os_info, devices)
    parallel(update_device, devices, max_workers=max_netbox_connections)


def update_ilo(devices):
    def get_ilo_ip(device):
        try:
            return socket.gethostbyname(f"{device.name}-ilo")
        except socket.gaierror:
            pass

    def ilo_link(device):
        return "https://" + socket.getfqdn(f"{device.name}-ilo")

    for device, ilo_ip in zip(devices, parallel(get_ilo_ip, devices)):
        if ilo_ip and ilo_link(device) != device.custom_fields.ilo_link:
            log.info(f"Saving {ilo_link(device)} as ILO address for {device} (current ILO link is {device.custom_fields.ilo_link})")
            nb.patch(f"devices/{device.id}", json_data={"custom_fields": {"ilo_link": ilo_link(device)}})
        else:
            print_testing(f"{device} has no ILO address or ILO link no changed")


def update_hardware(devices, force=False):
    def hw_info(device):
        """ Linux only, so far """
        if device.is_available:
            ret = {"custom_fields": {}}
            lshca_info = get_lshca(device)
            if lshca_info and "Driver" in lshca_info[0]:
                ret["mellanox_driver"] = lshca_info[0]["Driver"]
            ret["NICs"] = [{"card_name": nic["Desc"], "card_pn": nic["PN"], "card_sn": nic["SN"]} for nic in lshca_info]
            ret["GPUs"] = list(get_nvidia_gpus(device))
            ret["disks"] = get_drives(device)
            ret["CPU"] = get_lspcu(device)
            if is_vm(device):
                ret["Total size"] = get_total_size(device)
            else:
                ret["serial"] = get_system_sn(device)
                ret["Memory"] = {}
                ret["Memory"]["space (GB)"] = get_root_partition(device)
                ret["Memory"]["Total size"] = get_total_size(device)
            ret["custom_fields"]["inventory_os"] = get_os(device)
            device.os = ret["custom_fields"]["inventory_os"]
            ret["custom_fields"]["os_pretty_name"] = get_os_pretty_name(device)
            ret["custom_fields"]["mellanox_driver"] = ret.get("mellanox_driver")
            ret["custom_fields"]["cables"] = [c._asdict() for c in get_cables(device)]
            return ret
        else:
            print_warning(f"{device.name} will not be updated")

    def update_interfaces_info(device, hw):
        isvm = is_vm(device)
        cables = [CableInfo(**c) for c in hw["custom_fields"]["cables"]]  # converting cables dictionary back into CableInfo list
        new_cable_serials = [c.sn for c in cables]
        new_nic_names = [c.nic for c in cables]
        # removing existing interfaces or removing cable S/N from interfaces, if needed:
        for iface in nb.get_device_interfaces(device):
            # old cable S/N is not found on the interface:
            if iface.custom_fields.cable_sn and iface.custom_fields.cable_sn not in new_cable_serials:
                log.info(f"Removing cable S/N {iface.custom_fields.cable_sn} from {iface}")
                # for virtual machines should be an primary endpoint
                if not isvm:
                    nb.patch(f"interfaces/{iface.id}", json_data={"custom_fields": {"cable_sn": None}})
                else:
                    nb.virtualization.patch(f"interfaces/{iface.id}", \
                        json_data={"custom_fields": {"cable_sn": None}})
            # old interface itself is not found now:
            if iface.name not in new_nic_names:
                # delete auto discovered interfaces only:
                if iface.custom_fields["auto_discovered"]:
                    nb.delete_interface(iface)
            # new cable S/N found on the existing interface:
            if not iface.custom_fields.cable_sn and iface.name in new_nic_names:
                cable = [c for c in cables if c.nic == iface.name][0]
                if not isvm:
                    nb.patch(f"interfaces/{iface.id}", json_data={"custom_fields": {"cable_sn": cable.sn}})
                else:
                     nb.virtualization.patch(f"interfaces/{iface.id}", \
                         json_data={"custom_fields": {"cable_sn": cable.sn}})
        # creating newly found interfaces:
        create_missing_interfaces([device], isvms=isvm)

    def save_info(device, hw):
        if hw:
            old_data = get_json_comment(device)
            if old_data and "updated_at" in old_data:
                del old_data["updated_at"]
            new_comment_data = deepcopy(hw)
            new_comment_data["cables"] = [c["sn"] for c in hw["custom_fields"]["cables"]]
            del new_comment_data["custom_fields"]["cables"]
            if new_comment_data != old_data or force:
                print_warning("found changes", device.name)
                log.info(f"Saving hardware info for {device}: {new_comment_data}")
                new_comment_data["updated_at"] = datetime.now().isoformat(timespec="seconds")
                if is_vm(device):
                    disk_space = get_root_partition(device)
                    new_device_data = {
                    "memory": get_ram_size(device),
                    "vcpus": int(new_comment_data["CPU"]["sum of CPUs"]),
                    "disk": int(disk_space["free"]),
                    "comments": json.dumps(new_comment_data),
                    "custom_fields": hw["custom_fields"]
                    }
                    nb.virtualization.patch(f"virtual-machines/{device.id}" ,json_data=new_device_data)
                else:
                    new_device_data = {
                        "custom_fields": hw["custom_fields"],
                        "comments": json.dumps(new_comment_data),
                    }
                    if get_pci_gen(device):
                        new_device_data["platform"] = {"name": get_pci_gen(device)}
                    if hw.get("serial"):  # Netbox API doesn't allow serial=None
                        new_device_data["serial"] = hw.get("serial")
                    nb.patch(f"devices/{device.id}", json_data=new_device_data)
                update_interfaces_info(device, hw)
            else:
                print_testing(f"No changes found for {device}")

    enrich_with_availability(devices)
    enrich_with_os(devices)

    parallel(save_info, devices, parallel(hw_info, devices), max_workers=max_netbox_connections)
def convert_to_bitsize(size_str, size):
        size_str = size_str.strip().upper()
        
        # Define the units and their values in bytes
        units = {
            'B': 1,
            'K': 1024,
            'M': 1024 ** 2,
            'G': 1024 ** 3,
            'T': 1024 ** 4
        }
        
        # Extract the numeric value and unit
        for unit in units:
            if size_str.endswith(unit):
                try:
                    number = float(size_str[:-len(unit)])
                    return number * units[unit] / units[size]
                except ValueError:
                    return None
                
def get_root_partition(device, size_type="Gb"):
    # function written by Yoel brandsdorfer for support update_vm function

    output = ssh(device.name, "echo df -h /")
    if output and  output.startswith("Filesystem"):
        output = output.splitlines()
        if len(output) == 2 and output[1].endswith("/"):
            res = {
                "size": convert_to_bitsize(output[1].split()[1], size_type[0]),
                "used":convert_to_bitsize(output[1].split()[2], size_type[0]),
                "free": convert_to_bitsize(output[1].split()[3], size_type[0]),
                "percent_used": output[1].split()[4],
            }
            return res
        
def get_ram_size(device):
    # function written by Yoel brandsdorfer for support update_vm function
    output = ssh(device.name, "echo free -m")
    if output:
      return output.splitlines()[1].split()[1]

def get_total_size(device):
    # function written by Yoel brandsdorfer for support update_vm function
    output = ssh(device.name, "echo fdisk -l")
    if output and output.startswith("Disk /"):
        return output.splitlines()[0].split(":")[1].split(",")[0]

def get_ip_address(device, interface="", isvm=False):
    # function written by Yoel brandsdorfer for support update_vm function
    output = ssh(device.name, "echo hostname -I")
    enrich_with_interfaces([device], isvm=isvm)
    if output:
        data = output.split()[0]
        try:
            ipv4_obj = nb.ipam.ip_adreasses(ssigned_object_id=interface.id)
            if ipv4_obj :
                return  ipv4_obj
        except Exception as e:
            print_warning(f"Error getting {e}")
        endpoint = "virtualization" if isvm else "dcim"
        json_data = {                
        "address": data,
        "family": {
            "value": 4,
            "label": "IPv4"
        },
        "assigned_object_id": device.interface.id,
        "assigned_object_type": f"{endpoint}.interface"
        }
        ipv4_new_obj = nb.ipam.post("ip-addresses", json_data=json_data)
        return ipv4_new_obj
    
                 
def get_lspcu(device):
    # function written by Yoel brandsdorfer for support update_vm function
    output = ssh(device.name, "echo lscpu")
    res = {}
    if output:
        for line in output.splitlines():
            if line.startswith("Model name"):
                res["Model name"] = line.split(":")[1].strip()
            if line.startswith("CPU(s)"):
                res["sum of CPUs"] = line.split(":")[1].strip()
                
        return res
    

def get_json_comment(device):
    if device.comments and (device.comments.startswith("{") or device.comments.startswith("[")):
        return json.loads(device.comments)


def remove_dangling_cables():
    """ Find and remove the cables with auto_discovered=True and without
    cable S/N on all ends (interfaces) """

    ifaces_by_cable = {}
    iface_by_id = {i.id: i for i in nb.interfaces_cached()}
    for cable in nb.cables_cached():
        iface_ids = [i.object_id for i in cable.a_terminations if i.object_type == "dcim.interface"] \
            + [i.object_id for i in cable.b_terminations if i.object_type == "dcim.interface"]
        ifaces_by_cable[cable] = [iface_by_id[id] for id in iface_ids]

    def update_cable(cable):
        if cable.custom_fields.auto_discovered:

            ifaces = ifaces_by_cable[cable]
            ifaces_with_sn = [i for i in ifaces if i.custom_fields.cable_sn]
            if len(ifaces_with_sn) < 2:
                log.info(f"Deleting auto-discovered cable {cable} because it hasn't cable S/N on all ends (interfaces {[i.id for i in ifaces]})")
                nb.delete_cable(cable)

    log.info("Removing dangling cables")
    parallel(update_cable, nb.cables(), max_workers=max_netbox_connections)


def find_devices_by_cable(cable_sn):
    # return [d.name for d in nb.devices(q=cable_sn)]
    # return [(str(i), i.device.name) for i in nb.interfaces(cf_cable_sn=cable_sn)]
    return [i.device for i in nb.interfaces(cf_cable_sn=cable_sn)]


def diagnose(devices):
    update_hardware(devices, force=True)
    # update_interfaces(devices)
    enrich(devices)
    for d in devices:
        cables = get_cables(d)
        print(d.name)
        print(f"\tget_cables():\t{cables}")
        print(f"\tcables:\t{d.cables}")
        print(f"\tinterfaces:\t{[i.name for i in d.interfaces]}")
        for c in d.cables:
            print(f"\t{c.sn} connections: {[d.name for d in find_devices_by_cable(c.sn)]}")


def inspect(devices):
    def availability(device):
        return "alive" if device.is_available else "unavailable"

    enrich(devices)

    print("Same cable S/N found on multiple interfaces without connecting cable:")
    cables = set()
    for d in devices:
        ifaces = [i for i in d.interfaces if i.custom_fields.cable_sn and not i.cable]
        cables |= set([i.custom_fields.cable_sn for i in ifaces])
    for c in cables:
        matching_devices = find_devices_by_cable(c)
        if len(matching_devices) > 1:
            print(f"\t{c}\t{[d.name for d in matching_devices]}")

    print("Ports with cable S/N, but without connection on non-switch devices:")
    non_switches = [d for d in devices if not is_switch(d)]
    for d in non_switches:
        for iface in d.interfaces:
            if iface.custom_fields.cable_sn and not iface.cable:
                print(f"{d.name}\t{availability(d)}\t{iface}\thttp://swx-nbx.mtr.labs.mlnx/dcim/interfaces/{iface.id}/")


def start_shell(devices):
    # enrich(devices)
    import code
    import readline
    import rlcompleter

    vars = globals()
    vars.update(locals())

    readline.set_completer(rlcompleter.Completer(vars).complete)
    readline.parse_and_bind("tab: complete")
    code.InteractiveConsole(vars).interact()

def check_access(device):
    # check if device or switch is accessible by SSH    
    if not device.name:
        print_warning(f"Device name is not set.")
        return False

    # check if host is available
    if not host_available(device.name):
        print_warning(f"{device.name}: Host is not available.")
        return False
            
    status = ssh(device.name, "echo lspci -vmm", only_check=True)
    if isinstance(status, subprocess.CalledProcessError) and status.returncode == 5:
            print_warning(f"{device.name}: invalid credentials, please check credentials.")
            return False
    return True

def send_email_by_contact():
        contact_ids = [c.id for c in nb.tenancy.contacts()]
        all_contacts = nb.tenancy.contact_assignments()
        for contact_id in contact_ids:
            try:
                contact_devices = [nb.get_device_by_name(r.object.name) for r in all_contacts if r.object_type == "dcim.device" and r.contact.id == int(contact_id)]
                contact = nb.tenancy.contacts(contact_id)
                if contact_devices:
                    html_content = build_email_table(contact.name, contact_devices, ["Please review the status of your device.", "If it’s not in use, it should be decommissioned.","Thanks"])
                    send_mail("swx-ticket@nvidia.com",contact.email, "Devices status review", html_content, True)
                    print(f"email sent to {contact.name} at {contact.email}")
                else:
                    print_warning(f"no devices found for {contact.name}")
            except Exception as e:
                print_warning(e)

def print_warning(*content):
    print(termcolor.colored(f" WARNING!!:   {content}   ", "light_red", "on_yellow"))


def print_testing(*content):
    print(termcolor.colored(f"Test: {content}", "light_blue"))

def main():
    parser = argparse.ArgumentParser(
        "Inventory automation tool",
        formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument("action", choices=[
        "print",
        "notify-contacts",
        "update",
        "update-interfaces",
        "update-hardware",
        "update-vms",
        "cleanup",
        "shell",
        "diagnose",
        "inspect",
        "check-access",
        "send-mul-email",
        "test"
    ])
    parser.add_argument("-t", "--tag", help="retrieve devices with this tag only", default=None)
    parser.add_argument("-r", "--role", help="retrieve devices with this role only", default=None)
    parser.add_argument("-f", "--force", help="force database update, even if no hardware changes detected", action="store_true")
    parser.add_argument("-n", "--name", action="append", help="retrieve only this device (use several times for multiple devices)")
    parser.add_argument("-v", "--vm", action="append", help="retrieve only this virtual machines (use several times for multiple devices)")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("-d", "--debug", action="store_true", help="debug mode (very verbose)")
    group.add_argument("-s", "--silent", action="store_true", help="silent mode")
    args = parser.parse_args()

    log_level = logging.INFO
    if args.debug:
        log_level = logging.DEBUG
    elif args.silent:
        log_level = logging.WARNING
    configure_logging(log_level)

    system_audit()

    if args.name:
        devices = [nb.get_device_by_name(n) for n in args.name]
    elif not args.vm:
        ask_for_device = input(f"are you sure you want to {args.action} all devices? (y/n): ")
        
        if ask_for_device.lower() == "y":
            devices = nb.devices(tag=args.tag, role=args.role)
        else:
            print("goodbye! :(")
            return
    if args.vm:
        if args.vm[0] == "all" :
            vms = nb.virtualization.virtual_machines()
        else:
            vms = [nb.get_device_by_name(n) for n in args.vm]
        devices = vms

    log.info(f"Starting task {args.action} on {len(devices)} device(s)")
    if args.action == "print":
        enrich_with_os(devices)
        enrich_with_cables(devices)
        print("Name\tOS\tCables S/N")
        for d in devices:
            print(f"{d.name}\t{d.os}\t{[c.sn for c in d.cables]}")
    elif args.action == "notify-contacts":
        update_contact_info(devices)
    elif args.action == "update":
        update_hardware(devices, force=args.force)
        update_ilo(devices)
        update_diagrams(devices)
        update_interfaces(devices)
        remove_dangling_cables()
    elif args.action == "update-interfaces":
        update_diagrams(devices)
        update_interfaces(devices)
        remove_dangling_cables()
    elif args.action == "update-hardware":
        update_hardware(devices, force=args.force)
        update_ilo(devices)
    elif args.action == "update-vms":
        update_hardware(vms)
        update_interfaces(vms, True)
        enrich_with_cables(devices, isvms=True)
    elif args.action == "cleanup":
        cleanup(devices)
    elif args.action == "shell":
        start_shell(devices)
    elif args.action == "diagnose":
        diagnose(devices)
    elif args.action == "inspect":
        inspect(devices)
    elif args.action == "check-access":
        check_access(devices)
    elif args.action == "send-mul-email":
        ask = input(f"are you sure you want to send email to {[d.name for d in devices]} ?")
        if ask == "yes":
            send_email_by_contact()
    log.info("Done.")


if not log:
    configure_logging()
nb = NetboxClient("http://10.209.226.22", netbox_api_token)

if __name__ == "__main__":
    main()
