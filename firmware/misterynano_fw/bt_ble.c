/*
  bt_ble.c

  This was supposed to use joycon's. But it seems they use classic
  bluetooth and not bluetooth low energy which the bl616 only
  supports. Also _not_ working are the 8bitdo devices and most
  regular bluetooth keyboard and mice as they use classic
  BR/EDR bluetooth. The BL616 seems to be able to support this,
  but the bouffalolab SDK doesn't support it.

  This has been tested with two devices that implement BLE HID:

  - XZT mini bluetooth gamepad ($5 on aliexpress). This device works
    but will only report one button at a time. E.g. if you press a
    button while holding a direction active, the direction will
    return to 0 while the button is pressed. This device can act
    as a BLE gamepad or as a BLE mouse (and also as a BLE consumer
    device controller which this driver doesn't support)

  - A8 mini bluetooth keyboard dual mode (also on Aliexpress). This
    comes with a USB dongle but the dual mode version can also act
    as a bluetooth BLE device.
    
*/

#include <FreeRTOS.h>
#include <ctype.h>
#include "task.h"
#include "bt_ble.h"
#include "hid.h"

#include "bluetooth.h"
#include "conn.h"
#include "conn_internal.h"

#include "btble_lib_api.h"
#include "bl616_glb.h"
#include "rfparam_adapter.h"

#include "hci_driver.h"
#include "hci_core.h"
#include "gatt.h"
#include "bt_log.h"
#include "hidparser.h"

static spi_t *spi = NULL;

// -------------- list of found devices ------------------
static struct {
  int length;
  struct dev_S {
    bt_addr_le_t addr;

    // data from advertisement
    uint8_t valid;
    char name[30];
    uint16_t uuid;
    uint16_t appearance;

    // link to bt connection
    struct bt_conn *conn;

    // HID service start and end handles
    uint16_t srv_start_hnd;
    uint16_t srv_end_hnd;

    uint16_t hid_report_handle;

    // we support several reports    
    uint8_t report_cnt;
    struct report_S {
      hid_report_t descriptor;    
      uint16_t handle;
      uint8_t id;

      union {
	struct hid_kbd_state_S keyboard;
	struct hid_mouse_state_S mouse;
	struct hid_joystick_state_S joystick;
      };
    } *report;
  } *entries;
} devices = { .length = 0 };

// get our device entry from the bluetooth connection
static struct dev_S *get_device_by_conn(struct bt_conn *conn) {
  for(int i=0;i<devices.length;i++)
    if(devices.entries[i].conn == conn)
      return &devices.entries[i];

  return NULL;
}

const char* discovery_str[] = {
  "primary",
  "secondary",
  "include",
  "characteristic",
  "descriptor",
  "attribute",
};

static u16_t gatt_mtu_size;
static struct bt_gatt_discover_params discover_params;
static void ble_start_scan(void);
static void start_discovery(struct bt_conn *conn, u8_t type, uint16_t start, uint16_t end);

static void hexdump(const void *data, int size) {
  int i, b2c;
  int n=0;
  char *ptr = (char*)data;
  
  if(!size) return;
  
  while(size>0) {
    printf("%04x: ", n);

    b2c = (size>16)?16:size;
    for(i=0;i<b2c;i++)      printf("%02x ", 0xff&ptr[i]);
    printf("  ");
    for(i=0;i<(16-b2c);i++) printf("   ");
    for(i=0;i<b2c;i++)      printf("%c", isprint((int)ptr[i])?ptr[i]:'.');
    printf("\r\n");
    ptr  += b2c;
    size -= b2c;
    n    += b2c;
  }
}

static void print_chrc_props(u8_t properties) {
  printf("  Properties: ");
  
  if(properties & BT_GATT_CHRC_BROADCAST)          printf("[bcast]");
  if(properties & BT_GATT_CHRC_READ)               printf("[read]");
  if(properties & BT_GATT_CHRC_WRITE)              printf("[write]");
  if(properties & BT_GATT_CHRC_WRITE_WITHOUT_RESP) printf("[write w/o rsp]");
  if(properties & BT_GATT_CHRC_NOTIFY)             printf("[notify]");
  if(properties & BT_GATT_CHRC_INDICATE)           printf("[indicate]");
  if(properties & BT_GATT_CHRC_AUTH)               printf("[auth]");
  if(properties & BT_GATT_CHRC_EXT_PROP)           printf("[ext prop]");
  printf("\r\n");
}

struct report_desc_S {
  u16_t len;
  u8_t *data;
};

static struct report_desc_S *hid_report_buffer(bool init, const u8_t *data, u16_t len) {
  static struct report_desc_S desc = { .len=0, .data=NULL };

  if(data && len) {  
    if(init) desc.len = 0;

    // allocate additional space and append new data
    desc.data = realloc(desc.data, desc.len + len);
    memcpy(desc.data+desc.len, data, len);
    desc.len += len;
  }
    
  return &desc;
}

static u8_t gatt_read_hid_report_reference_cb(struct bt_conn *conn, u8_t err,
                  struct bt_gatt_read_params *params,
                  const void *data, u16_t length) {

  if (err || data == NULL || length == 0)
    return BT_GATT_ITER_STOP;
  
  //printf("report reference, len = %d\r\n", length);
  //hexdump(data, length);

  struct dev_S *dev = get_device_by_conn(conn);
  if(!dev) return BT_GATT_ITER_STOP;
  
  // search for matchig report entry
  for(int i=dev->report_cnt-1;i>=0;i--) {
    if(dev->report[i].handle < params->single.handle) {
      // the reference should return two bytes, the first one
      // being the report id, the second one being the direction
      // with 1 being in and 2 being out
      dev->report[i].id = *(unsigned char*)data;
      
      printf("  -> ID for handle %04x = %d\r\n",
	     dev->report[i].handle, dev->report[i].id);
      
      return BT_GATT_ITER_CONTINUE;
    }
  }
  
  return BT_GATT_ITER_CONTINUE;
}
  

static u8_t gatt_read_hid_report_descriptor_cb(struct bt_conn *conn, u8_t err,
                  struct bt_gatt_read_params *params,
                  const void *data, u16_t length) {

  struct dev_S *dev = get_device_by_conn(conn);
  if(!dev) return BT_GATT_ITER_STOP;
  
  // assemble everything into one buffer  
  hid_report_buffer(false, data, length);
  
  if (err || data == NULL || length == 0) {
    struct report_desc_S *rd = hid_report_buffer(false, NULL, 0);
    printf("Report descriptor done with %d bytes\r\n", rd->len);
    // hexdump(rd->data, rd->len);

    // search for gamepad usage in report descriptor
    uint16_t rbytes = 0;
    do {    
      hid_report_t hid_report;
      if(parse_report_descriptor(rd->data+rbytes, rd->len-rbytes, &hid_report, &rbytes)) {
	// we really need a report id to distinguish the reports
	if(hid_report.report_id_present) {	
	  printf("Report type %d ok, id=%d\r\n", hid_report.type, hid_report.report_id);

	  // check if we have a report entry for this descriptor
	  for(int i=0;i<dev->report_cnt;i++) {
	    if(dev->report[i].id == hid_report.report_id) {
	      printf(" -> matching handle %04x\r\n", dev->report[i].handle);
	      memcpy(&dev->report[i].descriptor, &hid_report, sizeof(hid_report_t));
	    }
	  }
	}
      }
    } while(rbytes < rd->len);

    
    return BT_GATT_ITER_STOP;
  }
  
  return BT_GATT_ITER_CONTINUE;
}  
    
static u8_t discover_func(struct bt_conn *conn, const struct bt_gatt_attr *attr, struct bt_gatt_discover_params *params) {
  struct bt_gatt_service_val *gatt_service;
  struct bt_gatt_chrc *gatt_chrc;
  struct bt_gatt_include *gatt_include;
  char str[37];
  struct dev_S *dev = get_device_by_conn(conn);

  if(!dev) {
    printf("device not found\r\n");
    return BT_GATT_ITER_STOP;
  }
  
  if (!attr) {
    printf( "Discover %s complete\r\n", discovery_str[discover_params.type]);

    // done with the primary
    if(discover_params.type == BT_GATT_DISCOVER_PRIMARY) {
      if(dev->srv_start_hnd && dev->srv_end_hnd) {      
	printf("Discover HID service characteristics from %04x to %04x ...\r\n",
	       dev->srv_start_hnd, dev->srv_end_hnd);
	dev->report_cnt = 0;
	dev->report = NULL;
	start_discovery(conn, BT_GATT_DISCOVER_CHARACTERISTIC, dev->srv_start_hnd, dev->srv_end_hnd);
      } else {
	printf("No HID service found\r\n");
	/* TODO: restart search */
      }
    }
    
    else if(discover_params.type == BT_GATT_DISCOVER_CHARACTERISTIC) {
      printf("Discover HID descriptors from %04x to %04x ...\r\n",
	     dev->srv_start_hnd, dev->srv_end_hnd);
      start_discovery(conn, BT_GATT_DISCOVER_DESCRIPTOR, dev->srv_start_hnd, dev->srv_end_hnd);
    }
      
    else {
      printf("Discovery done\r\n");
      
      memset(params, 0, sizeof(*params));

      // request and assemble hid resport descriptor
      hid_report_buffer(true, NULL, 0);   // reset report descriptor buffer
      static struct bt_gatt_read_params rparams;
      rparams.func = gatt_read_hid_report_descriptor_cb;
      rparams.handle_count = 1;
      rparams.single.handle = dev->hid_report_handle; // gatt_chrc->value_handle;
      rparams.single.offset = 0;
      
      int err = bt_gatt_read(conn, &rparams);
      if(err) printf("read (err %d)\r\n", err);
    }

    return BT_GATT_ITER_STOP;
  }
  
  switch (params->type) {
  case BT_GATT_DISCOVER_SECONDARY:
  case BT_GATT_DISCOVER_PRIMARY:
    gatt_service = attr->user_data;
    bt_uuid_to_str(gatt_service->uuid, str, sizeof(str));
    printf("Service %s found: start handle %04x, end_handle %04x\r\n",
	   str, attr->handle, gatt_service->end_handle);
    
    // we only care for service HID/0x1812
    if(bt_uuid_cmp(gatt_service->uuid, BT_UUID_DECLARE_16(0x1812)) == 0) {
      printf("HID service found!\r\n");
      dev->srv_start_hnd = attr->handle;
      dev->srv_end_hnd   = gatt_service->end_handle;
    }
    break;
    
  case BT_GATT_DISCOVER_CHARACTERISTIC:
    gatt_chrc = attr->user_data;
    bt_uuid_to_str(gatt_chrc->uuid, str, sizeof(str));
    printf("Characteristic %s found: attr->handle %04x  chrc->handle %04x \r\n",
	   str, attr->handle,gatt_chrc->value_handle);
    print_chrc_props(gatt_chrc->properties);

    // check for report map
    if(bt_uuid_cmp(gatt_chrc->uuid, BT_UUID_DECLARE_16(0x2a4b)) == 0) {
      printf("  -> hid report map at handle %04x\r\n", gatt_chrc->value_handle);
      dev->hid_report_handle = gatt_chrc->value_handle;      
    }
    
    if(bt_uuid_cmp(gatt_chrc->uuid, BT_UUID_DECLARE_16(0x2a4d)) == 0) {
      // "report"

      // allocate a new report entry
      dev->report_cnt++;
      dev->report = reallocarray(dev->report, dev->report_cnt, sizeof(struct report_S));
      memset(dev->report+dev->report_cnt-1, 0, sizeof(struct report_S));
      dev->report[dev->report_cnt-1].handle = gatt_chrc->value_handle;      

      printf("New report entry #%d for handle %04x\r\n", dev->report_cnt-1,
	     dev->report[dev->report_cnt-1].handle);
    }
    break;
    
  case BT_GATT_DISCOVER_INCLUDE:
    gatt_include = attr->user_data;
    bt_uuid_to_str(gatt_include->uuid, str, sizeof(str));
    printf("Include %s found: handle %04x, start %04x, end %04x\r\n", str, attr->handle,
	   gatt_include->start_handle, gatt_include->end_handle);
    break;

  case BT_GATT_DISCOVER_DESCRIPTOR:      
    bt_uuid_to_str(attr->uuid, str, sizeof(str));
    printf("Descriptor %s found: handle %04x\r\n", str, attr->handle);

    if(bt_uuid_cmp(attr->uuid, BT_UUID_DECLARE_16(0x2908)) == 0) {
      printf("  -> parsing hid report reference\r\n");

      static struct bt_gatt_read_params params;
      params.func = gatt_read_hid_report_reference_cb;
      params.handle_count = 1;
      params.single.handle = attr->handle;
      params.single.offset = 0;
      
      int err = bt_gatt_read(conn, &params);
      if(err) printf("read (err %d)\r\n", err);
    }
    break;
    
  default:
    break;
  }
  
  return BT_GATT_ITER_CONTINUE;
}

static void start_discovery(struct bt_conn *conn, u8_t type, uint16_t start, uint16_t end) {
  discover_params.func = discover_func;
  discover_params.start_handle = start;
  discover_params.end_handle = end;
  discover_params.type = type;
  discover_params.uuid = NULL;
  
  int err = bt_gatt_discover(conn, &discover_params);
  if(err) printf("Discover %s failed (err %d)\r\n", discovery_str[discover_params.type], err);
}

static void ble_connected(struct bt_conn *conn, u8_t err) {
  char addr[BT_ADDR_LE_STR_LEN];
  
  if(conn->type != BT_CONN_TYPE_LE) return;
  
  bt_addr_le_to_str(bt_conn_get_dst(conn), addr, sizeof(addr));
  if(err) {
    printf("Failed to connect to %s (%u)\r\n", addr, err);
    return;
  }
  
  printf("Connected: %s \r\n", addr);
  
  gatt_mtu_size = bt_gatt_get_mtu(conn);

  // start discover services
  start_discovery(conn, BT_GATT_DISCOVER_PRIMARY, 0x0001, 0xffff);
}

static void ble_disconnected(struct bt_conn *conn, u8_t reason) {
  char addr[BT_ADDR_LE_STR_LEN];
  
  if(conn->type != BT_CONN_TYPE_LE){
    return;
  }
  
  bt_addr_le_to_str(bt_conn_get_dst(conn), addr, sizeof(addr));
  printf("Disconnected: %s (reason %u) \r\n", addr, reason);
  
  if(conn->role == BT_HCI_ROLE_MASTER)
    bt_conn_unref(conn);
  
  // restart scan
  ble_start_scan();
}

static struct bt_conn_cb ble_conn_callbacks = {
  .connected	=   ble_connected,
  .disconnected	=   ble_disconnected,
};

static bool data_cb(struct bt_data *data, void *user_data) {
  struct dev_S *device = (struct dev_S*)user_data;
  
  // parse an entry. Return false to stop parsing  
  // printf("BT data_cb, type = 0x%02x\r\n", data->type);
  // hexdump(data->data, data->data_len);
  
  switch (data->type) {
  case BT_DATA_UUID16_SOME:
  case BT_DATA_UUID16_ALL:
    device->uuid = *(unsigned short*)data->data;
    device->valid |= 2;   // uuid now valid
    break;

  case BT_DATA_SVC_DATA16:
    // 03c1 == 961 -> Keyboard (HID subtype)
    device->appearance = *(unsigned short*)data->data;
    device->valid |= 4;   // appearance now valid
    break;
    
  case BT_DATA_NAME_SHORTENED:
  case BT_DATA_NAME_COMPLETE: {
    u8_t len = (data->data_len > 30 - 1)?(30 - 1):(data->data_len);
    memcpy(device->name, data->data, len);
    device->valid |= 1;   // name now valid
  } break;
    
  default:
    break;
  }
  return true;
}

static void device_found(const bt_addr_le_t *addr, s8_t rssi, u8_t evtype,
			 struct net_buf_simple *buf) {
  char le_addr[BT_ADDR_LE_STR_LEN];
  int ret;
  struct bt_le_conn_param param = {
    .interval_min =  BT_GAP_INIT_CONN_INT_MIN,
    .interval_max =  BT_GAP_INIT_CONN_INT_MAX,
    .latency = 0,
    .timeout = 400,
  };
  
  // check if this is a known device
  struct dev_S *dev = NULL;
  for(int i=0;i<devices.length;i++)
    if(bt_addr_le_cmp(&devices.entries[i].addr, addr) == 0)
      dev = &devices.entries[i];

  if(!dev) {  
    // allocate a new entry
    devices.length++;
    devices.entries = reallocarray(devices.entries, devices.length, sizeof(struct dev_S));
    memset(devices.entries+devices.length-1, 0, sizeof(struct dev_S));

    dev = &devices.entries[devices.length-1];    
    memset(dev, 0, sizeof(struct dev_S));	 

    // copy bt address
    bt_addr_le_copy(&dev->addr, addr);
  }

  // parse advertise payload
  bt_data_parse(buf, data_cb, dev);
  
  // TODO: This should go into the OSD, so the user can select a device ...
  // But for now just try to connect to the first available BLE HID device

  if((dev->valid & 2) && (dev->uuid == 0x1812)) {
    bt_addr_le_to_str(addr, le_addr, sizeof(le_addr));
    printf("[DEVICE FOUND]: %s, AD evt type %u, RSSI %i %s \r\n",le_addr, evtype, rssi, dev->name);
    
    // Stop scan 
    ret = bt_le_scan_stop();
    if(ret){
      printf("Stop scan fail err = %d\r\n", ret);
      return;
    }

    // Do connect
    dev->conn = bt_conn_create_le(addr, /*BT_LE_CONN_PARAM_DEFAULT*/&param);    
    
    if(!dev->conn) printf("Connection failed\r\n");
    else           printf("Connection starting\r\n");
  }
}

static void ble_start_scan(void) {
  int err = bt_le_scan_start(BT_LE_SCAN_ACTIVE, device_found);
  
  if(err) printf("Failed to start scan (err %d)\r\n", err);
  else    printf("Start scan successful\r\n");
}

static void bt_gatt_mtu_changed_cb(struct bt_conn *conn, int mtu) {
  printf("MTU changed to %d\r\n", mtu);
  gatt_mtu_size = mtu;
}

static void ble_notification_all_cb_t(struct bt_conn *conn, u16_t handle,const void *data, u16_t length) {
  struct dev_S *dev = get_device_by_conn(conn);
  if(!dev) return;
  
  // check if we have a matching hid report for this handle
  for(int i=0;i<dev->report_cnt;i++) {
    if(dev->report[i].handle == handle) {
      switch(dev->report[i].descriptor.type) {
      case REPORT_TYPE_JOYSTICK:
	printf("Joystick report on handle %04x\r\n", handle);
	joystick_parse(spi, &dev->report[i].descriptor, &dev->report[i].joystick, data, length);
	break;
      case REPORT_TYPE_KEYBOARD:
	printf("Keyboard report on handle %04x\r\n", handle);
	kbd_parse(spi, &dev->report[i].descriptor, &dev->report[i].keyboard, data, length);
	break;
      case REPORT_TYPE_MOUSE:
	printf("Mouse report on handle %04x\r\n", handle);
	mouse_parse(spi, &dev->report[i].descriptor, &dev->report[i].mouse, data, length);
	break;
      default:
	printf("Unknown report on handle %04x\r\n", handle);
	hexdump(data, length);
	break;
      }
    }
  }
}

void bt_br_discovery_cb(struct bt_br_discovery_result *results,
			size_t count) {
  printf("discovery results: %d\r\n", count);
}

void bt_enable_cb(int err) {
  if (!err) {    
#if 1
    // initiate LE scan    
    bt_addr_le_t bt_addr;
    bt_get_local_public_address(&bt_addr);
    
    char le_addr[BT_ADDR_LE_STR_LEN];
    bt_addr_le_to_str(&bt_addr, le_addr, sizeof(le_addr));
    printf("Local BD_ADDR: %s\r\n", le_addr);
    
    bt_conn_cb_register(&ble_conn_callbacks);
    bt_gatt_register_mtu_callback(bt_gatt_mtu_changed_cb);
    
    // start scanning
    ble_start_scan();
    
    // Register notification callback
    bt_gatt_register_notification_callback(ble_notification_all_cb_t);
#else
    // initiate BR/EDR scan
    struct bt_br_discovery_param param;
    param.length = 8;  // 10 seconds
    param.limited = false;

    static struct bt_br_discovery_result results[10];
    
    bt_br_discovery_start(&param, results, 10, bt_br_discovery_cb);
   
#endif
  }
}

static TaskHandle_t bt_ble_handle;

static void bt_ble_task(void *pvParameters) {
  printf("bt_ble controller init\r\n");
  btble_controller_init(configMAX_PRIORITIES - 1);

  // Initialize BLE Host stack
  hci_driver_init();
  bt_enable(bt_enable_cb);
    
  vTaskDelete(NULL);
}
  
void bt_ble_init(spi_t *spi_l) {
  printf("bt_ble_init()\r\n");

  spi = spi_l;
  
  /* Init rf */
  if (0 != rfparam_init(0, NULL, 0)) {
    printf("PHY RF init failed!\r\n");
    return;
  }

  xTaskCreate(bt_ble_task, (char *)"bt_ble_task", 1024, NULL, configMAX_PRIORITIES - 2, &bt_ble_handle);
}

