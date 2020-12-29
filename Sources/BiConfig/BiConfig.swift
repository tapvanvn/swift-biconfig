//
//  biconfig.swift
//
//  Created by Duy Nguyen on 7/4/19.
//  Copyright © 2019 Duy Nguyen. All rights reserved.
//

import Foundation

class IValue{
    var header:UInt8 = 0
    var header_length:UInt8 = 0
    var data:Data? = nil
    init(header:UInt8, header_length:UInt8, data:Data?)
    {
        self.header = header
        self.header_length = header_length
        self.data = data
    }
    
   
    var wrapData:Data
    {
        return Data.init()
    }
}

class I8Value: IValue
{
    init(data:Data?)
    {
        super.init(header: 0x21, header_length: 1, data:data)
    }
    override var wrapData:Data {
        get {
            var data = Data.init()
            data.append(header);
            let data_len:UInt8 = self.data == nil ? 0 : UInt8(self.data!.count)
            data.append( data_len.dataBE )
            data.append(self.data ?? Data.init())
            return data
        }
    }
}

class I16Value: IValue
{
    init(data:Data?)
    {
        super.init(header: 0x22, header_length: 2, data:data)
    }
    override var wrapData:Data {
        get {
            var data = Data.init()
            data.append(header);
            let data_len:UInt16 = self.data == nil ? 0 : UInt16(self.data!.count)
            data.append( data_len.dataBE )
            data.append(self.data ?? Data.init())
            return data
        }
    }
}


class I32Value: IValue
{
    
    init(data:Data?)
    {
        super.init(header: 0x23, header_length: 4, data:data)
    }
    override var wrapData:Data {
        get {
            var data = Data.init()
            data.append(header);
            let data_len:UInt32 = self.data == nil ? 0 : UInt32(self.data!.count)
            data.append( data_len.dataBE )
            data.append(self.data ?? Data.init())
            return data
        }
    }
}

class I64Value: IValue
{
    init(data:Data?)
    {
        super.init(header: 0x24, header_length: 8, data:data)
        self.data = data
    }
    override var wrapData:Data {
        get {
            var data = Data.init()
            data.append(header);
            let data_len:UInt64 = self.data == nil ? 0 : UInt64(self.data!.count)
            data.append( data_len.dataBE )
            data.append(self.data ?? Data.init())
            return data
        }
    }
}

class KeyValuePair
{
    var key:String? = nil;
    var value:IValue?
    init(key:String?, value:IValue?)
    {
        self.key = key
        self.value = value
    }
}

class Element
{
    var pair:KeyValuePair? = nil
    var next:Element? = nil
    
    init(pair:KeyValuePair)
    {
        self.pair = pair
        self.next = nil
    }
}

class Ledger
{
    var begin:Element? = nil
    var end:Element? = nil
    
    func loop( callback: (Element?)->Void )
    {
        var pointer:Element? = begin
        while(pointer != nil)
        {
            callback(pointer)
            pointer = pointer!.next
        }
    }
    
    func add(element:Element)
    {
        if(self.begin == nil)
        {
            self.begin =  element
            self.end = element
        }
        else
        {
             element.next = nil
            self.end!.next = element
            self.end = element
           
        }
    }
    
    func add(key:String?, value:IValue?)
    {
        let pair:KeyValuePair = KeyValuePair(key: key, value: value)
        let element:Element = Element.init(pair:pair)
        self.add(element: element)
    }
    
    func add(key:String?, value:UInt8)
    {
        self.add( key: key, value: I8Value.init( data: Data.init([value]) ) )
    }
    
    func add(key:String?, value:UInt16)
    {
        self.add(key:key, value: I8Value.init( data: value.dataBE ) )
    }
    
    func add(key:String?, value:UInt32)
    {
        self.add(key:key, value: I8Value.init( data: value.dataBE ) )
    }
    
    func add(key:String?, value:UInt64)
    {
        self.add(key:key, value: I8Value.init( data: value.dataBE ) )
    }
    
    func add(key:String?, data:Data)
    {
        if(data.count > UINT32_MAX)
        {
            self.add(key:key, value: I64Value(data:data))
        }
        else if(data.count > UINT16_MAX)
        {
            self.add(key:key, value: I32Value(data:data))
        }
        else if(data.count > UINT8_MAX)
        {
            self.add(key:key, value: I16Value(data:data));
        }
        else
        {
            self.add(key:key, value: I8Value(data:data));
        }
    }
    
    func addGroup(key:String?, sub_ledger:Ledger?)
    {
        self.add(key:key, value:nil)
        
        if(sub_ledger != nil && sub_ledger!.begin != nil)
        {
            if(self.begin == nil)
            {
                self.begin = sub_ledger!.begin;
            }
            else
            {
                self.end!.next = sub_ledger!.begin;
            }
            self.end = sub_ledger!.end;
            
            sub_ledger!.begin = nil
            sub_ledger!.end = nil
        }
        self.add(key:nil, value:nil)
    }
    
    func getUInt8(_ path:String, default_value:UInt8 = 0)->UInt8
    {

        if let data = self.get(path)
        {
            return data.uint8
        }
        else
        {
            debug(path)
        }
        return default_value
 
    }
    func getUInt16(_ path:String, default_value:UInt16 = 0)->UInt16
    {
        if let data = get(path)
        {
            return data.uint16FromBE
        }
        return default_value
    }
    func getUInt32(_ path:String, default_value:UInt32 = 0)->UInt32
    {
        if let data = self.get(path)
        {
            return data.uint32FromBE
        }
        return default_value
    }
    
    func getString(_ path:String, encoding:String.Encoding = .utf8, default_value:String = "" )->String?
    {
        if let data = get(path)
        {
           return NSString(data: data, encoding: encoding.rawValue) as String?
        }
        return default_value
    }
    
    func get(_ path:String)-> Data?
    {
        var nested_keys = path.split(separator: "/");
        var key_level:Int = 0;
        var group_level:Int = 0;
        
        var pointer = self.begin;
        while(nested_keys.count > 0)
        {
            let current_key = String(nested_keys.removeFirst());
            //if not same level of group so move to the correct level
            while(key_level != group_level && (pointer != nil))
            {
                if(pointer!.pair!.key == nil) //end group
                {
                    group_level -= 1;
                }
                else if(pointer!.pair!.value == nil) //begin group
                {
                    group_level += 1;
                }
                pointer = pointer!.next;
            }
            //find key begin from current pointer
            while(pointer != nil)
            {
                let element_key = pointer!.pair!.key;
                
                if(element_key != nil && element_key == current_key)
                {
                    //found element if no sub group request so return value
                    if(nested_keys.count == 0)
                    {
                        if ((pointer!.pair!.value) != nil)
                        {
                            return pointer!.pair!.value!.data;
                        }
                        return nil;
                    }
                    group_level += 1
                    break;
                }
                else
                {
                    //if we met a subgroup but not match the key so pass it
                    if(pointer!.pair!.value == nil)
                    {
                        var count_level = 1;
                        
                        while((pointer!.pair != nil) && count_level > 0)
                        {
                            if(pointer!.pair == nil)
                            {
                                count_level -= 1;
                            }
                            if(pointer!.pair != nil && pointer!.pair!.key != nil && pointer!.pair!.value == nil)
                            {
                                count_level += 1;
                            }
                            
                            pointer = pointer!.next;
                        }
                    }
                }
                pointer = pointer!.next;
            }
            
            key_level += 1;
        }
        return nil;
    }
    
    func debug(_ path:String)-> Data?
    {
        let console = Console.init(prefix: "")
        console.log( "forkey: \(path)")

        var pointer_1:Element? = begin
        while(pointer_1 != nil)
        {
            console.log( "- \(pointer_1?.pair?.key)")
            pointer_1 = pointer_1!.next
        }
        
        
        var nested_keys = path.split(separator: "/");
        var key_level:Int = 0;
        var group_level:Int = 0;
        
        var pointer = self.begin;
        while(nested_keys.count > 0)
        {
            let current_key = String(nested_keys.removeFirst());
            console.log("ledger   \(current_key) key_level:\(key_level) group_level:\(group_level)")
            //if not same level of group so move to the correct level
            while(key_level != group_level && (pointer != nil))
            {
                //console.log("here ==")
                if(pointer!.pair!.key == nil) //end group
                {
                    group_level -= 1;
                }
                else if(pointer!.pair!.value == nil) //begin group
                {
                    group_level += 1;
                }
                pointer = pointer!.next;
            }
            //find key begin from current pointer
            while(pointer != nil)
            {
                let element_key = pointer!.pair!.key;
                
                console.log("element_key \(element_key)")
                
                if(element_key != nil && element_key == current_key)
                {
                    //found element if no sub group request so return value
                    if(nested_keys.count == 0)
                    {
                        if ((pointer!.pair!.value) != nil)
                        {
                            console.log("ledger   found value \(pointer!.pair!.value!.data!.count)")
                            return pointer!.pair!.value!.data;
                        }

                        console.log("ledger   not found _")
                
                        return nil;
                    }
                    group_level += 1
                    break;
                }
                else
                {
                    //console.log("here")
                    //if we met a subgroup but not match the key so pass it
                    if(pointer!.pair!.value == nil)
                    {
                        //console.log("here _")
                        var count_level = 1;
                        
                        while((pointer!.pair != nil) && count_level > 0)
                        {
                            if(pointer!.pair == nil)
                            {
                                count_level -= 1;
                            }
                            if(pointer!.pair != nil && pointer!.pair!.key != nil && pointer!.pair!.value == nil)
                            {
                                count_level += 1;
                            }
                            
                            pointer = pointer!.next;
                        }
                    }
                }
                
                pointer = pointer!.next;
                
                if(pointer == nil)
                {
                    console.log("found nil");
                }
                
                if let debug_element_key = pointer?.pair?.key
                {
                    console.log("next debug key \(debug_element_key)")
                }
            }
            
            key_level += 1;
        }
        console.log("ledger   not found __")
        return nil;
    }
    
    var data: Data
    {
        get
        {
            var data = Data.init()
            
            var pointer = self.begin;
            
            while(pointer != nil)
            {
                if(pointer!.pair!.key != nil)
                {
                    data.append(0x01)
                    
                    if(pointer!.pair!.key != nil)
                    {
                    
                        let key_buff = pointer!.pair!.key!.data(using: String.Encoding.ascii)
                        data.append(key_buff!)
                    }

                    data.append(0x00)
                    
                    if(pointer!.pair!.value != nil)
                    {
                        let value_buff = pointer!.pair!.value!.wrapData

                        data.append(0x02)
                        data.append(value_buff)
                    }
                    
                }
                else if(pointer!.pair!.value == nil)
                {
                    data.append(contentsOf: [0x10])
                }
                
                pointer = pointer!.next;
            }
            
            return data;
        }
    }
}

class BiConfig
{

    static func readValue(it:inout Data.Iterator)->IValue?
    {
        let header = it.next()
        var data_buff = Data.init()
        
        if(header == 0x21)
        {
            let len:UInt8 = it.next()!;
            
            if(len > 0)
            {
                for _ in 1...len
                {
                    data_buff.append(it.next()!)
                }
            }

            return I8Value.init(data: data_buff);
        }
        else if(header == 0x22)
        {
            var len_buff:Data = Data.init()
            len_buff.append(it.next()!)
            len_buff.append(it.next()!)
            
            let len:UInt16 = len_buff.uint16FromBE
            
            if(len > 0)
            {
                for _ in 1...len
                {
                    data_buff.append(it.next()!)
                }
            }
            
            return I16Value.init(data: data_buff);
        }
        else if(header == 0x23)
        {
            var len_buff:Data = Data.init()
            len_buff.append(it.next()!)
            len_buff.append(it.next()!)
            len_buff.append(it.next()!)
            len_buff.append(it.next()!)

            
            let len:UInt32 = len_buff.uint32FromBE
            
            if(len > 0)
            {
                for _ in 1...len
                {
                    data_buff.append(it.next()!)
                }
            }
            
            return I32Value.init(data: data_buff);
        }
        else if(header == 0x24)
        {
            var len_buff:Data = Data.init()
            for _ in 1...8
            {
                len_buff.append(it.next()!)
            }
            
            let len:UInt32 = len_buff.uint32FromBE
            if(len > 0)
            {
                for _ in 1...len
                {
                    data_buff.append(it.next()!)
                }
            }
            
            return I32Value.init(data: data_buff);
        }
        return nil;
    }

    static func read(data:Data) ->Ledger?
    {
        let ledger = Ledger.init();
        var last_sign:UInt8? = 0x00;
        var curr_key:String? = nil;

        var it:Data.Iterator = data.makeIterator()
        var sign:UInt8? = it.next()
        
        while(sign != nil)
        {
            if(sign == 0x01)
            {
                //read key
                var key_buff = Data.init()
                var key_sign = it.next()
                while(key_sign != 0x00)
                {
                    key_buff.append(key_sign!)
                    key_sign = it.next()
                }
                let key = String.init(data: key_buff, encoding: String.Encoding.ascii)

                if(last_sign == 0x01)
                {
                    //if last sign is a key so we begin a sub group
                    let element = Element.init(pair: KeyValuePair.init(key: curr_key, value: nil));
                    ledger.add(element: element);
                }

                curr_key = key; //we dont need to delete last key here becouse it had beed used at other place.
            }
            else if(sign == 0x02)
            {
                let value = readValue(it: &it)
                let element = Element.init(pair: KeyValuePair.init(key: curr_key, value: value));
                ledger.add(element: element);
            }
            else if(sign == 0x10)
            {
                //end group
                let element = Element.init(pair: KeyValuePair.init(key: nil, value: nil));
                ledger.add(element: element);
            }
            last_sign = sign;
            sign = it.next()
        }
        return ledger;
    }

    static func unit_test ()
    {
        let buff = Data.init([
            0x01, 0x69, 0x70, 0x00,
            0x02, 0x21, 0x04, 0xC0, 0xA8, 0x01, 0x15,
            0x01, 0x73, 0x76, 0x00,
            0x01, 0x69, 0x70, 0x00,
            0x02, 0x21, 0x04, 0xC0, 0xA8, 0x01, 0x14,
            0x10
        ])

        let ledger = read(data: buff)
        
        ledger!.loop( callback: {(element:Element?)->Void in
            if(element!.pair!.key != nil)
            {
                print(element!.pair!.key! as String)
            }
        });

        let recheck_buff = ledger!.data
        print(recheck_buff.hexEncodedString())

        if(recheck_buff == buff )
        {
            print("passed")
        }
        else
        {
            print("fail")
        }
    }
}