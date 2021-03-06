/*
 * Copyright (c) 2017 Arm Limited and Contributors. All rights reserved.
 *
 * SPDX-License-Identifier: Apache-2.0
 * Licensed under the Apache License, Version 2.0 (the License); you may
 * not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an AS IS BASIS, WITHOUT
 * WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#ifndef MblCloudClient_h_
#define MblCloudClient_h_

#include "mbed-cloud-client/MbedCloudClient.h"

#include "MblError.h"
#include "MblMutex.h"
#include "cloud-connect-resource-broker/MblCloudConnectResourceBroker.h"

#include <stdint.h>

extern "C" void mbl_shutdown_handler(int signal);

namespace mbl {

class MblCloudClient {

public:
    static MblError run();

private:
    enum State
    {
        State_Unregistered,
        State_CalledRegister,
        State_Registered
    };

    struct InstanceScoper
    {
        InstanceScoper();
        ~InstanceScoper();
    };

    // Only InstanceScoper can create or destroy objects
    MblCloudClient();
    ~MblCloudClient();

    // No copying
    MblCloudClient(const MblCloudClient& other);
    MblCloudClient& operator=(const MblCloudClient& other);

    void register_handlers();
    void add_resources();
    MblError cloud_client_setup();

    static void handle_client_registered();
    static void handle_client_unregistered();
    static void handle_error(int error_code);
    static void handle_authorize(int32_t request);

    MbedCloudClient* cloud_client_;
    State state_;

    // Mbl Cloud Connect Resource Broker
    // - Parse resource definition JSON file that received from an application as part of the RegisterResources request.
    // - Handle all requests from applications to MbedCloudClient.
    // - Handling observers notifications from MbedCloudClient to applications.
    // - Perform access right checks for all application requests.
    // - Maintain database of all application resources per application. The database also contains resource properties (for example allowed methods: GET, PUT, POST). The database will NOT contain current resource values.
    // - Perform multiplexing and de-multiplexing of messages between MbedCloudClient and applications.    
    MblCloudConnectResourceBroker cloud_connect_resource_broker_;

    static MblCloudClient* s_instance;
    static MblMutex s_mutex;
};

} // namespace mbl

#endif // MblCloudClient_h_
