/*
 * Infomaniak kDrive - Desktop
 * Copyright (C) 2023-2025 Infomaniak Network SA
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */

#pragma once

#include "libcommon/utility/types.h"

namespace KDC {

struct FSOperation {
    public:
        FSOperation(OperationType operationType, const NodeId &nodeId, NodeType objectType = NodeType::Unknown,
                    SyncTime createdAt = 0, SyncTime lastModified = 0, int64_t size = 0, const SyncPath &path = "",
                    const SyncPath &destinationPath = "");

        [[nodiscard]] UniqueId id() const { return _id; }
        [[nodiscard]] OperationType operationType() const { return _operationType; }
        [[nodiscard]] NodeId nodeId() const { return _nodeId; }
        [[nodiscard]] NodeType objectType() const { return _objectType; }
        [[nodiscard]] SyncTime createdAt() const { return _createdAt; }
        [[nodiscard]] SyncTime lastModified() const { return _lastModified; }
        [[nodiscard]] int64_t size() const { return _size; }
        [[nodiscard]] SyncPath path() const { return _path; }
        [[nodiscard]] SyncPath destinationPath() const { return _destinationPath; }

        [[nodiscard]] bool canWrite() const { return _canWrite; }
        void setCanWrite(const bool canWrite) { _canWrite = canWrite; }
        [[nodiscard]] bool canShare() const { return _canShare; }
        void setCanShare(const bool canShare) { _canShare = canShare; }

        bool operator==(const FSOperation &o) const {
            return this->_operationType == o._operationType && this->_nodeId == o._nodeId;
        }

    private:
        UniqueId _id{0};
        OperationType _operationType{OperationType::None};
        NodeId _nodeId;
        NodeType _objectType{NodeType::Unknown};
        SyncTime _createdAt{0};
        SyncTime _lastModified{0};
        int64_t _size{0};
        SyncPath _path;
        SyncPath _destinationPath;

        bool _canWrite{true};
        bool _canShare{true};

        static UniqueId _nextId;
};

} // namespace KDC
