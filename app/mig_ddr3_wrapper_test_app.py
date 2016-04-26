#!/usr/bin/python
#
# The MIT License (MIT)
#
# Copyright (c) 2016 Jakub Cabal <xcabal05@stud.feec.vutbr.cz>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.
#
# Website: https://github.com/jakubcabal/mig_ddr3_wrapper_virtex6
#-------------------------------------------------------------------------------

import time
import serial
import binascii

def send_byte(data):
    send_data = binascii.unhexlify(format(data,'02x'))
    uart.write(send_data)

def read_bytes(NumBytes, RAW=False):
    read_data = uart.read(NumBytes)
    hex_data = binascii.hexlify(read_data)
    int_data = int(hex_data,16)
    if RAW:
        return hex_data
    else:
        return int_data

#####################################################################

print("PROSIM PRIPOJTE VYVOJOVOU DESKU ML605 NA SERIOVY PORT COM1 A ZVOLTE TEST:\n")
print("1 - Sekvencni zapis")
print("2 - Sekvencni cteni")
print("3 - Sekvencni zapis a cteni v pomeru 1:1")
test_number = input("\nZADEJTE CISLO VYBRANEHO TESTU: ")

uart = serial.Serial('COM1', 115200, parity=serial.PARITY_EVEN, timeout=1) # open serial port
#print('UART ON ' + uart.name + ' IS OPEN')

test_duration = 4.0

# print '\nONE WRITE AND ONE READ TEST'
# send_byte(0x0F) # RESET ALL COUNTERS
# send_byte(0x01) # ONE WRITE
# send_byte(0x02) # ONE READ
# send_byte(0x21) # READ COUNT WRITE REQUESTS
# wr_req_cnt = read_bytes(4)
# send_byte(0x22) # READ COUNT READ REQUESTS
# rd_req_cnt = read_bytes(4)
# send_byte(0x23) # READ COUNT READ RESPONSES
# rd_resp_cnt = read_bytes(4)
# print 'WRITE DATA REQUESTS:', wr_req_cnt
# print 'READ DATA REQUESTS:',rd_req_cnt
# print 'READ DATA RESPONSES:',rd_resp_cnt
# send_byte(0x24) # READ LAST DATA PART
# last_data = read_bytes(4, True)
# print 'LAST READ DATA PART (CORRECT DATA = 01234567):',last_data

if test_number == 1:
    print '\nTEST SEKVENCNIHO ZAPISU'
    send_byte(0x0F) # RESET ALL COUNTERS
    send_byte(0x11) # START TEST
    time.sleep(test_duration)
    send_byte(0x10) # STOP TEST
    send_byte(0x21) # READ COUNT WRITE REQUESTS
    wr_req_cnt = read_bytes(4)
    wr_data_speed = ((wr_req_cnt*64)/(test_duration*1e9))
    print 'POCET ZAPISOVYCH POZADAVKU:', wr_req_cnt
    print 'RYCHLOST ZAPISU:', wr_data_speed, 'GB/s'

elif test_number == 2:
    print '\nTEST SEKVECNIHO CTENI'
    send_byte(0x0F) # RESET ALL COUNTERS
    send_byte(0x12) # START TEST
    time.sleep(test_duration)
    send_byte(0x10) # STOP TEST
    time.sleep(test_duration)
    send_byte(0x22) # READ COUNT READ REQUESTS
    rd_req_cnt = read_bytes(4)
    send_byte(0x23) # READ COUNT READ RESPONSES
    rd_resp_cnt = read_bytes(4)
    rd_data_speed = ((rd_resp_cnt*64)/(test_duration*1e9))
    print 'POCET CTECICH POZADAVKU:',rd_req_cnt
    print 'POCET CTECICH ODPOVEDI:',rd_resp_cnt
    print 'RYCHLOST CTENI:', rd_data_speed, 'GB/s'

else:
    print '\nTEST SEKVENCNIHO ZAPISU A CTENI V POMERU 1:1'
    send_byte(0x0F) # RESET ALL COUNTERS
    send_byte(0x13) # START TEST
    time.sleep(test_duration)
    send_byte(0x10) # STOP TEST
    send_byte(0x21) # READ COUNT WRITE REQUESTS
    wr_req_cnt = read_bytes(4)
    send_byte(0x22) # READ COUNT READ REQUESTS
    rd_req_cnt = read_bytes(4)
    send_byte(0x23) # READ COUNT READ RESPONSES
    rd_resp_cnt = read_bytes(4)
    wr_data_speed = ((wr_req_cnt*64)/(test_duration*1e9))
    rd_data_speed = ((rd_resp_cnt*64)/(test_duration*1e9))
    print 'POCET ZAPISOVYCH POZADAVKU:', wr_req_cnt
    print 'RYCHLOST ZAPISU:', wr_data_speed, 'GB/s'
    print 'POCET CTECICH POZADAVKU:',rd_req_cnt
    print 'POCET CTECICH ODPOVEDI:',rd_resp_cnt
    print 'RYCHLOST CTENI:', rd_data_speed, 'GB/s'

uart.close()
raw_input("\nPRO KONEC PROGRAMU ZMACKNETE LIBOVOLNOU KLAVESU...")